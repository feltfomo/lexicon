use crate::{
    model::{Manifest, Parameter, Result, fail},
    ui::output,
};
use std::collections::BTreeMap;

fn choices(p: &Parameter) -> Vec<String> {
    if p.sensitive {
        vec![]
    } else if !p.choices.is_empty() {
        p.choices.clone()
    } else if p.kind == "bool" {
        vec!["true".into(), "false".into()]
    } else {
        vec![]
    }
}
fn parameter_values(p: &Parameter, prefix: &str) -> Vec<String> {
    if p.kind != "path" || !p.choices.is_empty() {
        return choices(p);
    }
    let (parent, leaf) = prefix
        .rsplit_once('/')
        .map_or(("", prefix), |(p, f)| (&prefix[..p.len() + 1], f));
    let directory = if parent.is_empty() { "." } else { parent };
    std::fs::read_dir(directory)
        .into_iter()
        .flatten()
        .take(10000)
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let name = entry.file_name().into_string().ok()?;
            if !name.starts_with(leaf) {
                return None;
            }
            Some(format!(
                "{parent}{name}{}",
                if entry.path().is_dir() { "/" } else { "" }
            ))
        })
        .collect()
}
fn matching(mut values: Vec<String>, prefix: &str) -> Vec<String> {
    // line protocols cannot carry terminal controls or record separators
    values.retain(|value| value.starts_with(prefix) && !value.chars().any(char::is_control));
    values.sort();
    values.dedup();
    values
}
fn literals(values: &[&str], prefix: &str) -> Vec<String> {
    matching(values.iter().map(|v| (*v).to_owned()).collect(), prefix)
}
fn runner_inline(prefix: &str) -> Option<Vec<String>> {
    let (flag, value) = prefix.split_once('=')?;
    Some(
        literals(crate::ui::option_values(flag)?, value)
            .into_iter()
            .map(|v| format!("{flag}={v}"))
            .collect(),
    )
}
pub fn candidates(
    manifest: &Manifest,
    aliases: &BTreeMap<String, String>,
    words: &[String],
) -> Vec<String> {
    use crate::{arguments::ParameterIndex, ui};
    let (prefix, previous) = words
        .split_last()
        .map_or(("", &[][..]), |(p, rest)| (p.as_str(), rest));
    let mut cursor = 0;
    let mut options = ui::Options::default();
    while let Some(word) = previous.get(cursor).filter(|w| w.starts_with('-')) {
        if let Some(values) = ui::option_values(word)
            && cursor + 1 == previous.len()
        {
            return literals(values, prefix);
        }
        if options.take(previous, &mut cursor).ok() != Some(true) {
            return vec![];
        }
        cursor += 1;
    }
    let names = || {
        manifest
            .commands
            .iter()
            .filter(|(_, c)| !c.hidden)
            .flat_map(|(name, c)| {
                std::iter::once(name.as_str()).chain(c.aliases.iter().map(String::as_str))
            })
    };
    let Some(action) = previous.get(cursor) else {
        return runner_inline(prefix).unwrap_or_else(|| {
            if prefix.starts_with('-') {
                literals(ui::RUNNER_FLAGS, prefix)
            } else {
                matching(
                    ui::ACTIONS
                        .iter()
                        .copied()
                        .chain(names())
                        .filter(|name| name.starts_with(prefix))
                        .map(str::to_owned)
                        .collect(),
                    prefix,
                )
            }
        });
    };
    if action == "completions" {
        return literals(
            if previous.len() == cursor + 1 {
                &["fish", "bash", "zsh"]
            } else {
                &["--wrappers"]
            },
            prefix,
        );
    }
    let name = if matches!(action.as_str(), "show" | "plan" | "run" | "doctor" | "help") {
        cursor += 1;
        let Some(name) = previous.get(cursor) else {
            return matching(
                names()
                    .filter(|name| name.starts_with(prefix))
                    .map(str::to_owned)
                    .collect(),
                prefix,
            );
        };
        name
    } else if ui::ACTIONS.contains(&action.as_str()) {
        return runner_inline(prefix).unwrap_or_else(|| literals(ui::RUNNER_FLAGS, prefix));
    } else {
        action
    };
    let canonical = aliases.get(name).unwrap_or(name);
    let Some(command) = manifest.commands.get(canonical) else {
        return vec![];
    };
    if command.hidden || matches!(action.as_str(), "show" | "help") {
        return vec![];
    }
    let parameters = ParameterIndex::new(&command.parameters);
    let forwarding = command.forwarding();
    let mut positional = 0;
    cursor += 1;
    while let Some(word) = previous.get(cursor) {
        if word == "--" {
            return vec![];
        }
        if let Some((parameter, inline)) = parameters.flag(word) {
            if inline.is_none() && parameter.kind != "bool" {
                if cursor + 1 == previous.len() {
                    return matching(parameter_values(parameter, prefix), prefix);
                }
                cursor += 1;
            }
        } else if parameters.positional(word, positional).is_some() {
            positional += 1;
        } else if forwarding {
            return vec![];
        }
        cursor += 1;
    }
    if let Some((parameter, Some(value))) = parameters.flag(prefix) {
        let flag = &prefix[..prefix.len() - value.len()];
        return matching(parameter_values(parameter, value), value)
            .into_iter()
            .map(|v| format!("{flag}{v}"))
            .collect();
    }
    if prefix.starts_with('-') {
        let mut values = Vec::new();
        for p in command
            .parameters
            .iter()
            .filter(|p| !p.positional && !p.sensitive)
        {
            values.push(format!("--{}", p.name));
            if let Some(short) = p.short {
                values.push(format!("-{short}"));
            }
        }
        // negative positional choices share a prefix with named flags
        if let Some(parameter) = parameters
            .positionals
            .get(positional)
            .filter(|p| p.kind == "int")
        {
            values.extend(parameter_values(parameter, prefix));
        }
        matching(values, prefix)
    } else {
        parameters
            .positionals
            .get(positional)
            .map_or_else(Vec::new, |p| matching(parameter_values(p, prefix), prefix))
    }
}
pub fn generate(manifest: &Manifest, shell: &str, wrappers: bool) -> Result<()> {
    let prefix = &manifest.name;
    // dispatcher installation must not replace native tools' completion functions
    let names = manifest
        .commands
        .iter()
        .filter(|(_, c)| wrappers && !c.hidden)
        .map(|(n, _)| n.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    let text = match shell {
        "fish" => format!(
            r#"function __{prefix}_candidates
  set -l words (commandline -opc)
  set -l current (commandline -ct)
  set -l invoked (path basename -- "$words[1]")
  if test "$invoked" = {prefix}
    command "$words[1]" complete -- $words[2..] "$current" | string escape
  else
    set -l dispatcher {prefix}
    if string match -q '*/*' -- "$words[1]"
      set dispatcher (path dirname -- "$words[1]")/{prefix}
    end
    command "$dispatcher" complete -- run "$invoked" $words[2..] "$current" | string escape
  end
end
complete -c {prefix} -f -a '(__{prefix}_candidates)'
for cmd in {names}
  complete -c $cmd -f -a '(__{prefix}_candidates)'
end
"#
        ),
        // readline splits at equals even though it belongs to the parameter token
        "bash" => format!(
            r#"_{prefix}_complete() {{
  local -a words=()
  local word previous current i dispatcher={prefix}
  for word in "${{COMP_WORDS[@]:1:COMP_CWORD}}"; do
    previous=
    if (( ${{#words[@]}} )); then previous=${{words[-1]}}; fi
    if [[ $word == = && $previous == -* ]]; then
      words[-1]+='='
    elif [[ $previous == -*= ]]; then
      words[-1]+=$word
    else
      words+=("$word")
    fi
  done
  if [[ ${{COMP_WORDS[0]##*/}} == {prefix} ]]; then
    mapfile -t COMPREPLY < <("${{COMP_WORDS[0]}}" complete -- "${{words[@]}}")
  else
    if [[ ${{COMP_WORDS[0]}} == */* ]]; then dispatcher="${{COMP_WORDS[0]%/*}}/{prefix}"; fi
    mapfile -t COMPREPLY < <("$dispatcher" complete -- run "${{COMP_WORDS[0]##*/}}" "${{words[@]}}")
  fi
  current=${{COMP_WORDS[COMP_CWORD]}}
  if [[ $current == = || ( $COMP_CWORD -gt 0 && ${{COMP_WORDS[COMP_CWORD-1]}} == = ) ]]; then
    for i in "${{!COMPREPLY[@]}}"; do COMPREPLY[i]=${{COMPREPLY[i]#*=}}; done
  fi
}}
complete -F _{prefix}_complete {prefix} {names}
"#
        ),
        "zsh" => format!(
            r#"#compdef {prefix} {names}
_{prefix}_complete() {{
  local -a candidates
  local dispatcher={prefix}
  if [[ ${{words[1]:t}} == {prefix} ]]; then
    candidates=("${{(@f)$("${{words[1]}}" complete -- "${{words[@]:1:$((CURRENT - 1))}}")}}")
  else
    if [[ ${{words[1]}} == */* ]]; then dispatcher="${{words[1]:h}}/{prefix}"; fi
    candidates=("${{(@f)$("$dispatcher" complete -- run "${{words[1]:t}}" "${{words[@]:1:$((CURRENT - 1))}}")}}")
  fi
  compadd -- "${{candidates[@]}}"
}}
compdef _{prefix}_complete {prefix} {names}
# autoload must answer the first request, not just register the function
if [[ ${{funcstack[1]-}} == _{prefix} ]]; then
  _{prefix}_complete "$@"
fi
"#
        ),
        _ => return Err(fail(64, "supported completion shells: fish, bash, zsh")),
    };
    output(&text)
}
