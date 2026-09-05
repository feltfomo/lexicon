use crate::interaction::Policy;
use crate::model::{Notifications, Parameter, Result, Ui, clean, fail};
use serde::Serialize;
use std::io::{self, IsTerminal, Write};

pub const OUTPUT_MODES: &[&str] = &["concise", "verbose", "quiet", "plain", "json"];
pub const COLOR_MODES: &[&str] = &["auto", "always", "never"];
pub const NOTIFY_MODES: &[&str] = &["never", "success", "failure", "always"];
pub const RUNNER_FLAGS: &[&str] = &[
    "--help",
    "--yes",
    "--non-interactive",
    "--concise",
    "--plain",
    "--verbose",
    "--quiet",
    "--json",
    "--output",
    "--color",
    "--no-progress",
    "--notify",
    "--bell",
];
pub fn option_values(flag: &str) -> Option<&'static [&'static str]> {
    match flag {
        "--output" => Some(OUTPUT_MODES),
        "--color" => Some(COLOR_MODES),
        "--notify" => Some(NOTIFY_MODES),
        _ => None,
    }
}
#[derive(Default)]
pub struct Options {
    pub ui: Ui,
    pub policy: Policy,
    pub help: bool,
    pub all: bool,
    pub complete: bool,
    pub json_errors: bool,
}
impl Options {
    pub fn take(&mut self, args: &[String], index: &mut usize) -> Result<bool> {
        let (flag, inline) = args[*index]
            .split_once('=')
            .map_or((args[*index].as_str(), None), |(k, v)| (k, Some(v)));
        let mut value = || -> Result<String> {
            if let Some(value) = inline {
                return Ok(value.to_owned());
            }
            *index += 1;
            args.get(*index)
                .cloned()
                .ok_or_else(|| fail(64, format!("{flag} needs a value")))
        };
        match flag {
            "--output" => self.ui.output = Some(value()?),
            "--color" => self.ui.color = Some(value()?),
            "--notify" => {
                let mode = value()?;
                if !NOTIFY_MODES.contains(&mode.as_str()) {
                    return Err(fail(64, "notify expects never, success, failure or always"));
                }
                let n = self
                    .ui
                    .notifications
                    .get_or_insert_with(Notifications::default);
                n.desktop = Some(mode != "never");
                n.success = Some(matches!(mode.as_str(), "success" | "always"));
                n.failure = Some(matches!(mode.as_str(), "failure" | "always"));
            }
            "--concise" | "--verbose" | "--quiet" | "--plain" | "--json" if inline.is_none() => {
                self.ui.output = Some(flag[2..].into())
            }
            "-v" if inline.is_none() => self.ui.output = Some("verbose".into()),
            "-q" if inline.is_none() => self.ui.output = Some("quiet".into()),
            "--yes" | "-y" if inline.is_none() => self.policy.yes = true,
            "--non-interactive" if inline.is_none() => self.policy.non_interactive = true,
            "--help" | "-h" if inline.is_none() => self.help = true,
            "--all" if inline.is_none() => self.all = true,
            "--complete" if inline.is_none() => self.complete = true,
            "--no-progress" if inline.is_none() => self.ui.progress = Some(false),
            "--bell" if inline.is_none() => {
                self.ui
                    .notifications
                    .get_or_insert_with(Notifications::default)
                    .bell = Some(true)
            }
            _ => return Ok(false),
        }
        if self
            .ui
            .output
            .as_deref()
            .is_some_and(|v| !OUTPUT_MODES.contains(&v))
        {
            return Err(fail(64, "unknown output mode"));
        }
        if self
            .ui
            .color
            .as_deref()
            .is_some_and(|v| !COLOR_MODES.contains(&v))
        {
            return Err(fail(64, "unknown color mode"));
        }
        Ok(true)
    }
    pub fn split(&mut self, args: &[String], parameters: &[Parameter]) -> Result<Vec<String>> {
        let parameters = crate::arguments::ParameterIndex::new(parameters);
        let mut kept = Vec::with_capacity(args.len());
        let mut index = 0;
        while index < args.len() {
            if args[index] == "--" {
                kept.extend_from_slice(&args[index..]);
                break;
            }
            // a parameter value can have the same spelling as a runner option
            if let Some((parameter, inline)) = parameters.flag(&args[index]) {
                kept.push(args[index].clone());
                if inline.is_none() && parameter.kind != "bool" {
                    index += 1;
                    kept.push(
                        args.get(index)
                            .ok_or_else(|| fail(64, "parameter needs a value"))?
                            .clone(),
                    );
                }
            } else if !self.take(args, &mut index)? {
                kept.push(args[index].clone());
            }
            index += 1;
        }
        Ok(kept)
    }
}
pub fn output(text: &str) -> Result<()> {
    io::stdout()
        .lock()
        .write_all(text.as_bytes())
        .map_err(|e| fail(74, e.to_string()))
}
pub fn json(value: &impl Serialize) -> Result<()> {
    let mut writer = io::BufWriter::new(io::stdout().lock());
    serde_json::to_writer(&mut writer, value).map_err(|e| fail(74, e.to_string()))?;
    writer
        .write_all(b"\n")
        .and_then(|_| writer.flush())
        .map_err(|e| fail(74, e.to_string()))
}
pub fn color(ui: &Ui) -> bool {
    !matches!(ui.mode(), "plain" | "json")
        && ui.color.as_deref() != Some("never")
        && std::env::var_os("NO_COLOR").is_none()
        && std::env::var_os("CI").is_none()
        && std::env::var("TERM").as_deref() != Ok("dumb")
        && (ui.color.as_deref() == Some("always") || io::stderr().is_terminal())
}
pub fn event(
    ui: &Ui,
    event: &str,
    command: &str,
    label: &str,
    index: usize,
    total: usize,
    seconds: f64,
) -> Result<()> {
    if ui.mode() == "json" {
        return json(
            &serde_json::json!({"event":event,"command":command,"label":label,"index":index,"total":total,"seconds":seconds}),
        );
    }
    if ui.mode() == "quiet" || ui.progress == Some(false) {
        return Ok(());
    }
    let state = if color(ui) {
        format!(
            "\x1b[{}m{event}\x1b[0m",
            if event == "failed" { "31" } else { "36" }
        )
    } else {
        event.into()
    };
    eprintln!("{state} [{index}/{total}] {} ({seconds:.2}s)", clean(label));
    Ok(())
}
