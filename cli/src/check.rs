// the check built-in realises every published check. omitted outputs are not
// part of the check set.

use crate::backend::Backend;
use crate::commands;
use crate::diagnostics::{self, Diagnostic};

pub const USAGE: &str = "lexicon check [flake]";

#[derive(Debug, PartialEq, Eq)]
pub struct Request {
    pub flake: String,
}

pub fn parse(arguments: &[String]) -> Result<Request, String> {
    let mut flake: Option<String> = None;

    for argument in arguments {
        match argument.as_str() {
            "check" if flake.is_none() => {}
            held if held.starts_with("--") => {
                return Err(format!("{held} is not something lexicon reads, {USAGE}"))
            }
            held if flake.is_none() => flake = Some(held.to_string()),
            held => return Err(format!("{held} is one flake too many, {USAGE}")),
        }
    }

    Ok(Request {
        flake: flake.unwrap_or_else(|| ".".to_string()),
    })
}

pub fn execute<Held: Backend>(
    backend: &Held,
    system: &str,
    request: &Request,
) -> Result<Option<String>, String> {
    let locked = backend
        .lock(&request.flake)
        .map_err(|refusal| refusal.to_string())?;

    // a declared check can never win against the built-in, so this warning is
    // the only place the person learns why theirs did not run.
    for collision in commands::shadows(backend, &locked, system) {
        eprintln!("{collision}");
    }

    let at = format!("checks.{system}");

    let names = backend
        .attrs(&locked, &at)
        .map_err(|refusal| refusal.to_string())?;

    let refused: Vec<Diagnostic> = names
        .iter()
        .filter_map(|name| realised(backend, &locked, &at, name).err())
        .collect();

    if refused.is_empty() {
        Ok(None)
    } else {
        let written: Vec<String> = refused.iter().map(Diagnostic::to_string).collect();

        Ok(Some(written.join("\n")))
    }
}

fn realised<Held: Backend>(
    backend: &Held,
    locked: &crate::backend::Locked,
    at: &str,
    name: &str,
) -> Result<(), Diagnostic> {
    let path = format!("{at}.{name}");

    // inspect drvPath before realising so non-store values get a check error.
    let described = backend.walk(locked, &format!("{path}.drvPath"))?;

    let drv = described.text().ok_or_else(|| {
        Diagnostic::new(
            diagnostics::CHECK_REFUSED,
            &["checks", name],
            format!("{name} is nothing a store can hold"),
        )
    })?;

    backend.realise(locked, &path).map_err(|refusal| {
        Diagnostic::new(
            diagnostics::CHECK_REFUSED,
            &["checks", name],
            format!("{name} was not built from {drv}, {}", refusal.message),
        )
    })?;

    println!("{name} held");

    Ok(())
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::*;
    use crate::backend::Locked;
    use crate::json::Value;

    struct Rehearsed {
        names: Vec<String>,
        refuses: Vec<String>,
    }

    impl Backend for Rehearsed {
        fn lock(&self, flake: &str) -> Result<Locked, Diagnostic> {
            Ok(Locked {
                reference: flake.to_string(),
                tree: "/nix/store/held".to_string(),
            })
        }

        fn attrs(&self, _locked: &Locked, path: &str) -> Result<Vec<String>, Diagnostic> {
            if path.starts_with("checks.") {
                Ok(self.names.clone())
            } else {
                Ok(vec!["check".to_string(), "greet".to_string()])
            }
        }

        fn walk(&self, _locked: &Locked, path: &str) -> Result<Value, Diagnostic> {
            Ok(Value::Text(format!("/nix/store/{}.drv", path.len())))
        }

        fn realise(&self, _locked: &Locked, path: &str) -> Result<PathBuf, Diagnostic> {
            if self.refuses.iter().any(|held| path.ends_with(held)) {
                Err(Diagnostic::new(
                    diagnostics::OUTPUT_UNREADABLE,
                    &[path],
                    "the build failed",
                ))
            } else {
                Ok(PathBuf::from("/nix/store/held"))
            }
        }
    }

    #[test]
    fn the_flake_defaults_to_the_tree_the_binary_was_run_in() {
        let request = parse(&[]).expect("the arguments were refused");

        assert_eq!(request.flake, ".");
    }

    #[test]
    fn a_flake_is_read_when_one_is_written() {
        let request = parse(&["path:/held".to_string()]).expect("the arguments were refused");

        assert_eq!(request.flake, "path:/held");
    }

    #[test]
    fn every_published_check_is_realised_and_a_quiet_run_reports_nothing() {
        let backend = Rehearsed {
            names: vec!["one".to_string(), "two".to_string()],
            refuses: Vec::new(),
        };

        let outcome = execute(&backend, "x86_64-linux", &parse(&[]).expect("refused"));

        assert_eq!(outcome, Ok(None));
    }

    #[test]
    fn a_check_that_was_not_built_is_reported_under_its_own_name() {
        let backend = Rehearsed {
            names: vec!["one".to_string(), "two".to_string()],
            refuses: vec!["two".to_string()],
        };

        let outcome = execute(&backend, "x86_64-linux", &parse(&[]).expect("refused"))
            .expect("the check was refused")
            .expect("the run was quiet");

        assert!(outcome.contains(diagnostics::CHECK_REFUSED));
        assert!(outcome.contains("$.checks.two"));
        assert!(!outcome.contains("$.checks.one"));
    }
}
