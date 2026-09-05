use crate::{
    model::{Manifest, Result, clean, fail},
    plan, run,
};
use std::io::{self, Write};
fn output(text: &str) -> Result<()> {
    io::stdout()
        .lock()
        .write_all(text.as_bytes())
        .map_err(|e| fail(74, e.to_string()))
}
fn help(manifest: &Manifest, name: &str) -> Result<()> {
    let command = manifest
        .commands
        .get(name)
        .ok_or_else(|| fail(64, format!("unknown command {name}")))?;
    let mut text = format!(
        "{}\n\nUsage: {} [--plain] [--yes]",
        clean(&command.description),
        name
    );
    for p in &command.parameters {
        text.push_str(&format!(
            " {}{}{}",
            if p.required { "<" } else { "[" },
            if p.positional {
                p.name.clone()
            } else {
                format!(
                    "--{}{}",
                    p.name,
                    if p.kind == "bool" { "" } else { " VALUE" }
                )
            },
            if p.required { ">" } else { "]" }
        ));
    }
    if command.steps.iter().any(|s| s.forward_args) {
        text.push_str(" [-- ARGS...]");
    }
    text.push_str("\n\n  --help   Show command help\n  --plain  Disable terminal colors\n  --yes    Accept declared confirmations\n");
    for p in &command.parameters {
        text.push_str(&format!(
            "  {} ({})  {}{}\n",
            p.name,
            p.kind,
            clean(&p.description),
            p.default
                .as_ref()
                .map_or(String::new(), |v| format!(" [default: {}]", clean(v)))
        ));
    }
    output(&text)
}
pub fn dispatch(manifest: &Manifest, args: Vec<String>) -> Result<()> {
    let Some(action) = args.first().map(String::as_str) else {
        return usage();
    };
    match action {
        "--help" | "help" => usage(),
        "--version" => output(concat!("praxis ", env!("CARGO_PKG_VERSION"), "\n")),
        "list" if args.len() == 1 => output(
            &manifest
                .commands
                .iter()
                .map(|(name, command)| format!("{name}\t{}\n", clean(&command.description)))
                .collect::<String>(),
        ),
        "show" if args.len() == 2 => help(manifest, &args[1]),
        "completions" if args.len() == 2 => completions(manifest, &args[1]),
        "run" | "plan" => {
            let name = args
                .get(1)
                .ok_or_else(|| fail(64, format!("{action} needs a command name")))?;
            let mut plain = false;
            let mut yes = false;
            let mut command_args = Vec::new();
            let mut rest = false;
            for arg in &args[2..] {
                if rest {
                    command_args.push(arg.clone());
                    continue;
                }
                match arg.as_str() {
                    "--" => {
                        rest = true;
                        command_args.push(arg.clone());
                    }
                    "--help" => return help(manifest, name),
                    "--plain" => plain = true,
                    "--yes" => yes = true,
                    _ => command_args.push(arg.clone()),
                }
            }
            let plan = plan::build(manifest, name, &command_args)?;
            if action == "plan" {
                let mut writer = io::BufWriter::new(io::stdout().lock());
                serde_json::to_writer_pretty(&mut writer, &plan)
                    .map_err(|e| fail(if e.is_io() { 74 } else { 65 }, e.to_string()))?;
                writer
                    .write_all(b"\n")
                    .and_then(|_| writer.flush())
                    .map_err(|e| fail(74, e.to_string()))
            } else {
                run::execute(&plan, plain, yes)
            }
        }
        _ => Err(fail(
            64,
            "usage: praxis list | show NAME | plan NAME | run NAME | completions fish|bash|zsh",
        )),
    }
}
fn usage() -> Result<()> {
    output(
        "Praxis runs your declared commands.\n\n  praxis list\n  praxis show NAME\n  praxis plan NAME [ARGS]\n  praxis run NAME [--plain] [--yes] [ARGS]\n  praxis completions fish|bash|zsh\n",
    )
}
fn completions(manifest: &Manifest, shell: &str) -> Result<()> {
    let names = manifest
        .commands
        .keys()
        .cloned()
        .collect::<Vec<_>>()
        .join(" ");
    let mut text = String::new();
    match shell {
        "fish" => {
            text.push_str("complete -c praxis -f -n '__fish_use_subcommand' -a 'list show plan run completions'\n");
            text.push_str(&format!("complete -c praxis -f -n '__fish_seen_subcommand_from run show plan' -a '{names}'\n"));
            for (name, command) in &manifest.commands {
                for target in [
                    format!("-c {name}"),
                    format!("-c praxis -n '__fish_seen_subcommand_from {name}'"),
                ] {
                    for flag in ["help", "plain", "yes"] {
                        text.push_str(&format!("complete {target} -l {flag}\n"));
                    }
                    for p in command.parameters.iter().filter(|p| !p.positional) {
                        text.push_str(&format!(
                            "complete {target} -l {} {}\n",
                            p.name,
                            if p.kind == "bool" {
                                ""
                            } else if p.kind == "path" {
                                "-r -F"
                            } else {
                                "-r"
                            }
                        ));
                    }
                }
            }
        }
        "bash" | "zsh" => {
            if shell == "zsh" {
                text.push_str("autoload -Uz bashcompinit; bashcompinit\n");
            }
            text.push_str(&format!(
                "complete -W 'list show plan run completions {names}' praxis\n"
            ));
            for (name, command) in &manifest.commands {
                let flags = command
                    .parameters
                    .iter()
                    .filter(|p| !p.positional)
                    .map(|p| format!("--{}", p.name))
                    .collect::<Vec<_>>()
                    .join(" ");
                text.push_str(&format!(
                    "complete -W '--help --plain --yes {flags}' {name}\n"
                ));
            }
        }
        _ => return Err(fail(64, "supported completion shells: fish, bash, zsh")),
    }
    output(&text)
}
