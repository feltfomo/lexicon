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
    while let Some(word) = previous.get(cursor).filter(|w| w.starts_with('-')) {
        if let Some(values) = ui::option_values(word) {
            if cursor + 1 == previous.len() {
                return literals(values, prefix);
            }
            cursor += 1;
        }
        cursor += 1;
    }
    let Some(action) = previous.get(cursor) else {
        return runner_inline(prefix).unwrap_or_else(|| {
            if prefix.starts_with('-') {
                literals(ui::RUNNER_FLAGS, prefix)
            } else {
                literals(
                    &["list", "show", "plan", "run", "doctor", "completions"],
                    prefix,
                )
            }
        });
    };
    if action == "completions" {
        return literals(&["fish", "bash", "zsh"], prefix);
    }
    if !matches!(action.as_str(), "show" | "plan" | "run" | "doctor") {
        return runner_inline(prefix).unwrap_or_else(|| literals(ui::RUNNER_FLAGS, prefix));
    }
    let Some(name) = previous.get(cursor + 1) else {
        return matching(
            manifest
                .commands
                .iter()
                .filter(|(_, c)| !c.hidden)
                .flat_map(|(name, c)| std::iter::once(name.clone()).chain(c.aliases.clone()))
                .collect(),
            prefix,
        );
    };
    let canonical = aliases.get(name).unwrap_or(name);
    let Some(command) = manifest.commands.get(canonical) else {
        return vec![];
    };
    if command.hidden {
        return vec![];
    }
    let parameters = ParameterIndex::new(&command.parameters);
    let mut positional = 0;
    cursor += 2;
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
        } else if let Some(values) = ui::option_values(word) {
            if cursor + 1 == previous.len() {
                return literals(values, prefix);
            }
            cursor += 1;
        } else if !word.starts_with('-') || word.parse::<i64>().is_ok() {
            positional += 1;
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
    if let Some(values) = runner_inline(prefix) {
        return values;
    }
    if prefix.starts_with('-') {
        let mut values = ui::RUNNER_FLAGS
            .iter()
            .map(|v| (*v).to_owned())
            .collect::<Vec<_>>();
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
        // negative positional choices share a prefix with runner flags
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
pub fn generate(manifest: &Manifest, shell: &str) -> Result<()> {
    let names = manifest
        .commands
        .iter()
        .filter(|(_, c)| !c.hidden)
        .map(|(n, _)| n.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    let text = match shell {
        "fish" => format!(
            r#"function __praxis_candidates
  set -l words (commandline -opc)
  set -l current (commandline -ct)
  if test (path basename -- "$words[1]") = praxis
    command "$words[1]" complete -- $words[2..] "$current" | string escape
  else
    command "$words[1]" --complete -- $words[2..] "$current" | string escape
  end
end
complete -c praxis -f -a '(__praxis_candidates)'
for cmd in {names}
  complete -c $cmd -f -a '(__praxis_candidates)'
end
"#
        ),
        // readline splits at equals even though it belongs to the parameter token
        "bash" => format!(
            r#"_praxis_complete() {{
  local -a words=()
  local word previous current i
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
  if [[ ${{COMP_WORDS[0]##*/}} == praxis ]]; then
    mapfile -t COMPREPLY < <("${{COMP_WORDS[0]}}" complete -- "${{words[@]}}")
  else
    mapfile -t COMPREPLY < <("${{COMP_WORDS[0]}}" --complete -- "${{words[@]}}")
  fi
  current=${{COMP_WORDS[COMP_CWORD]}}
  if [[ $current == = || ( $COMP_CWORD -gt 0 && ${{COMP_WORDS[COMP_CWORD-1]}} == = ) ]]; then
    for i in "${{!COMPREPLY[@]}}"; do COMPREPLY[i]=${{COMPREPLY[i]#*=}}; done
  fi
}}
complete -F _praxis_complete praxis {names}
"#
        ),
        "zsh" => format!(
            r#"#compdef praxis {names}
_praxis_complete() {{
  local -a candidates
  if [[ ${{words[1]:t}} == praxis ]]; then
    candidates=("${{(@f)$("${{words[1]}}" complete -- "${{words[@]:1:$((CURRENT - 1))}}")}}")
  else
    candidates=("${{(@f)$("${{words[1]}}" --complete -- "${{words[@]:1:$((CURRENT - 1))}}")}}")
  fi
  compadd -- "${{candidates[@]}}"
}}
compdef _praxis_complete praxis {names}
"#
        ),
        _ => return Err(fail(64, "supported completion shells: fish, bash, zsh")),
    };
    output(&text)
}
