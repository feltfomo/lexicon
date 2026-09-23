// the binary resolves built-ins before flake-declared commands. fmt also
// accepts the path form nix fmt uses when it invokes the formatter.

pub mod backend;
pub mod check;
pub mod commands;
pub mod diagnostics;
pub mod fmt;
pub mod json;
pub mod run;
pub mod select;
pub mod tools;

use std::path::Path;

// TODO fmt stays here because its wrapper pins the bytes it runs. other
// built-ins may read their configuration from the flake.
pub const BUILTINS: [&str; 2] = ["fmt", "check"];

pub const USAGE: &str =
    "lexicon fmt [--check] [path ...]\nlexicon check [flake]\nlexicon <command> [argument ...]";

pub fn is_builtin(name: &str) -> bool {
    BUILTINS.contains(&name)
}

#[derive(Debug, PartialEq, Eq)]
pub enum Request {
    Fmt(fmt::Request),
    Check(check::Request),
    Declared(commands::Request),
}

pub fn parse(arguments: &[String]) -> Result<Request, String> {
    parse_with(arguments, |held| Path::new(held).exists())
}

// whether a first word is a path cannot be answered from the words alone, so
// the caller answers it and the suite answers it without a tree
pub fn parse_with<Reaches>(arguments: &[String], reaches: Reaches) -> Result<Request, String>
where
    Reaches: Fn(&str) -> bool,
{
    match arguments.first().map(String::as_str) {
        Some("fmt") => fmt::parse(&arguments[1..]).map(Request::Fmt),
        Some("check") => check::parse(&arguments[1..]).map(Request::Check),
        Some(held) if !held.starts_with('-') && !reaches(held) => {
            Ok(Request::Declared(commands::parse(held, &arguments[1..])))
        }
        _ => fmt::parse(arguments).map(Request::Fmt),
    }
}

// the flake is read for the running system. rust calls darwin macos.
pub fn system() -> String {
    let kernel = match std::env::consts::OS {
        "macos" => "darwin",
        held => held,
    };

    format!("{}-{kernel}", std::env::consts::ARCH)
}

pub fn execute(request: &Request) -> Result<Option<String>, String> {
    match request {
        Request::Fmt(held) => fmt::execute(held),
        Request::Check(held) => check::execute(&backend::Subprocess::new(), &system(), held),
        Request::Declared(held) => {
            commands::execute(&backend::Subprocess::new(), ".", &system(), held)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn nothing_reaches(_held: &str) -> bool {
        false
    }

    #[test]
    fn the_builtins_are_a_table_and_not_one_special_case() {
        assert!(is_builtin("fmt"));
        assert!(is_builtin("check"));
        assert!(!is_builtin("greet"));
    }

    #[test]
    fn no_arguments_is_formatting_because_nix_fmt_writes_none() {
        let held = parse_with(&[], nothing_reaches).expect("the arguments were refused");

        assert!(matches!(held, Request::Fmt(_)));
    }

    #[test]
    fn a_builtin_is_resolved_before_anything_the_flake_declares() {
        let held =
            parse_with(&["check".to_string()], |_| true).expect("the arguments were refused");

        assert!(matches!(held, Request::Check(_)));
    }

    #[test]
    fn a_word_that_is_no_path_and_no_builtin_is_a_declared_command() {
        let held = parse_with(
            &["greet".to_string(), "--loudly".to_string()],
            nothing_reaches,
        )
        .expect("the arguments were refused");

        assert_eq!(
            held,
            Request::Declared(commands::Request {
                name: "greet".to_string(),
                arguments: vec!["--loudly".to_string()],
            })
        );
    }

    #[test]
    fn a_word_that_is_a_path_is_formatting_and_not_a_command() {
        let held =
            parse_with(&["one.nix".to_string()], |_| true).expect("the arguments were refused");

        assert!(matches!(held, Request::Fmt(_)));
    }

    #[test]
    fn a_flag_is_read_as_formatting_because_nix_fmt_writes_flags_too() {
        let held = parse_with(&["--check".to_string()], nothing_reaches)
            .expect("the arguments were refused");

        assert_eq!(
            held,
            Request::Fmt(fmt::Request {
                mode: fmt::Mode::Check,
                paths: Vec::new(),
            })
        );
    }
}
