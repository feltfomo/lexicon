// the formatter accepts both the explicit subcommand and nix fmt's path form.

use std::path::PathBuf;

use crate::{run, select};

pub const USAGE: &str = "lexicon fmt [--check] [path ...]";

#[derive(Debug, PartialEq, Eq)]
pub enum Mode {
    Write,
    Check,
}

#[derive(Debug, PartialEq, Eq)]
pub struct Request {
    pub mode: Mode,
    pub paths: Vec<PathBuf>,
}

pub fn parse(arguments: &[String]) -> Result<Request, String> {
    let mut mode = Mode::Write;
    let mut paths = Vec::new();
    let mut seen_subcommand = false;

    for argument in arguments {
        match argument.as_str() {
            "fmt" if !seen_subcommand && paths.is_empty() => seen_subcommand = true,
            "--check" => mode = Mode::Check,
            held if held.starts_with("--") => {
                return Err(format!("{held} is not something lexicon reads, {USAGE}"))
            }
            held => paths.push(PathBuf::from(held)),
        }
    }

    Ok(Request { mode, paths })
}

// report every file that would change so one check gives a complete result.
pub fn execute(request: &Request) -> Result<Option<String>, String> {
    let files = select::select(&request.paths)
        .map_err(|failure| format!("the files to format could not be read, {failure}"))?;

    match request.mode {
        Mode::Write => run::format(&files).map(|()| None),
        Mode::Check => run::would_change(&files).map(|changed| {
            if changed.is_empty() {
                None
            } else {
                let named: Vec<String> = changed
                    .iter()
                    .map(|path| path.display().to_string())
                    .collect();

                Some(format!(
                    "these files are not formatted\n{}",
                    named.join("\n")
                ))
            }
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_arguments_formats_the_whole_tree() {
        let request = parse(&[]).expect("the arguments were refused");

        assert_eq!(request.mode, Mode::Write);
        assert!(request.paths.is_empty());
    }

    #[test]
    fn the_subcommand_is_optional_because_nix_fmt_does_not_write_it() {
        let written =
            parse(&["fmt".to_string(), "one.nix".to_string()]).expect("the arguments were refused");
        let bare = parse(&["one.nix".to_string()]).expect("the arguments were refused");

        assert_eq!(written, bare);
    }

    #[test]
    fn check_formats_nothing() {
        let request = parse(&["--check".to_string()]).expect("the arguments were refused");

        assert_eq!(request.mode, Mode::Check);
    }

    #[test]
    fn paths_are_taken_in_the_order_they_were_written() {
        let request = parse(&["one.nix".to_string(), "two.nix".to_string()])
            .expect("the arguments were refused");

        assert_eq!(
            request.paths,
            vec![PathBuf::from("one.nix"), PathBuf::from("two.nix")]
        );
    }

    #[test]
    fn an_unread_flag_is_refused_rather_than_taken_as_a_path() {
        assert!(parse(&["--write".to_string()]).is_err());
    }

    // the formatting check runs where no client is, so formatting must not
    // acquire a dependency on one
    #[test]
    fn a_missing_client_is_inert_for_formatting() {
        let refusal =
            crate::backend::resolved_with(|| Some(String::new())).expect_err("a client was found");

        assert_eq!(refusal.code, crate::diagnostics::NIX_ABSENT);

        let request = parse(&["--check".to_string()]).expect("the arguments were refused");

        let held = std::env::temp_dir().join(format!("lexicon-inert-{}", std::process::id()));

        std::fs::create_dir_all(&held).expect("the scratch tree was refused");
        std::fs::write(held.join("notes.md"), "held\n").expect("the file was refused");

        let asked = Request {
            mode: request.mode,
            paths: vec![held.clone()],
        };

        let outcome = execute(&asked);

        let _ = std::fs::remove_dir_all(&held);

        assert_eq!(outcome, Ok(None));
    }
}
