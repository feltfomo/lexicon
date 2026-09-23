// declared commands come from lexicon.apps and run without a shell.

use std::os::unix::process::CommandExt;
use std::process::Command;

use crate::backend::{Backend, Locked};
use crate::diagnostics::{self, Diagnostic};
use crate::json::Value;

#[derive(Debug, PartialEq, Eq)]
pub struct Request {
    pub name: String,
    pub arguments: Vec<String>,
}

pub fn parse(name: &str, arguments: &[String]) -> Request {
    Request {
        name: name.to_string(),
        arguments: arguments.to_vec(),
    }
}

fn published(system: &str) -> String {
    format!("lexicon.apps.{system}")
}

pub fn shadowed(names: &[String]) -> Vec<Diagnostic> {
    names
        .iter()
        .filter(|name| crate::is_builtin(name))
        .map(|name| {
            Diagnostic::new(
                diagnostics::COMMAND_SHADOWS_BUILTIN,
                &["commands", name],
                format!("the declared command {name} is also a built-in of lexicon"),
            )
            .helped(format!(
                "the built-in runs. rename the declared command and call it by the new name, or run it with nix run .#{name}"
            ))
        })
        .collect()
}

// a flake outside lexicon publishes no command list and must stay legal, so
// an unreadable list shadows nothing rather than failing the built-in.
pub fn shadows<Held: Backend>(backend: &Held, locked: &Locked, system: &str) -> Vec<Diagnostic> {
    match discover(backend, locked, system) {
        Ok(names) => shadowed(&names),
        Err(_) => Vec::new(),
    }
}

pub fn discover<Held: Backend>(
    backend: &Held,
    locked: &Locked,
    system: &str,
) -> Result<Vec<String>, Diagnostic> {
    backend.attrs(locked, &published(system))
}

pub fn program<Held: Backend>(
    backend: &Held,
    locked: &Locked,
    system: &str,
    name: &str,
) -> Result<String, Diagnostic> {
    let at = format!("{}.{name}", published(system));

    let held = backend.walk(locked, &at)?;

    let kind = held.field("type").and_then(Value::text);

    if kind != Some("app") {
        return Err(Diagnostic::new(
            diagnostics::COMMAND_MALFORMED,
            &["apps", name],
            format!(
                "{name} is not an app, it is {}",
                kind.unwrap_or("nothing named")
            ),
        ));
    }

    let program = held
        .field("program")
        .and_then(Value::text)
        .ok_or_else(|| {
            Diagnostic::new(
                diagnostics::COMMAND_MALFORMED,
                &["apps", name],
                format!("{name} names no program"),
            )
        })?
        .to_string();

    // the walk names a store path that need not be built yet, so it is
    // realised before the process is replaced.
    backend.realise(locked, &format!("{at}.program"))?;

    Ok(program)
}

pub fn execute<Held: Backend>(
    backend: &Held,
    flake: &str,
    system: &str,
    request: &Request,
) -> Result<Option<String>, String> {
    let locked = backend.lock(flake).map_err(|refusal| refusal.to_string())?;

    let names = discover(backend, &locked, system).map_err(|refusal| refusal.to_string())?;

    for collision in shadowed(&names) {
        eprintln!("{collision}");
    }

    if !names.iter().any(|held| held == &request.name) {
        return Err(Diagnostic::new(
            diagnostics::COMMAND_UNKNOWN,
            &["commands", &request.name],
            format!("{} is no command this flake declares", request.name),
        )
        .helped(format!("the flake declares {}", names.join(", ")))
        .to_string());
    }

    let program =
        program(backend, &locked, system, &request.name).map_err(|refusal| refusal.to_string())?;

    // replace the process so arguments and exit status pass through with no
    // shell between.
    let failure = Command::new(&program).args(&request.arguments).exec();

    Err(format!("{program} could not be run, {failure}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_declared_name_that_is_a_builtin_is_reported_under_the_shadow_code() {
        let held = shadowed(&["greet".to_string(), "check".to_string()]);

        assert_eq!(held.len(), 1);
        assert_eq!(held[0].code, diagnostics::COMMAND_SHADOWS_BUILTIN);
        assert_eq!(held[0].place(), "$.commands.check");
    }

    #[test]
    fn declared_names_that_shadow_nothing_are_quiet() {
        assert!(shadowed(&["greet".to_string()]).is_empty());
    }

    #[test]
    fn discovery_reads_lexicons_own_projection_and_not_the_top_level() {
        assert_eq!(published("x86_64-linux"), "lexicon.apps.x86_64-linux");
    }
}
