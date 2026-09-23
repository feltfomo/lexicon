// TODO a second evaluator joins by implementing four primitives, lock a
// flake, list output attributes, walk a value, and realise a derived path.
// checks, diagnostics, and exclusions belong above this seam.

use std::path::{Path, PathBuf};
use std::process::Command;

use crate::diagnostics::{self, Diagnostic};
use crate::json::{self, Value};

// the reference and store tree returned by flake metadata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Locked {
    pub reference: String,
    pub tree: String,
}

pub trait Backend {
    fn lock(&self, flake: &str) -> Result<Locked, Diagnostic>;

    fn attrs(&self, locked: &Locked, path: &str) -> Result<Vec<String>, Diagnostic>;

    fn walk(&self, locked: &Locked, path: &str) -> Result<Value, Diagnostic>;

    fn realise(&self, locked: &Locked, path: &str) -> Result<PathBuf, Diagnostic>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct Subprocess;

impl Subprocess {
    pub fn new() -> Self {
        Subprocess
    }
}

// nix is read off the path rather than pinned by the wrapper, because it has
// to be the client the caller's daemon speaks to
pub fn client() -> Result<PathBuf, Diagnostic> {
    resolved_with(|| std::env::var_os("PATH").map(|held| held.to_string_lossy().to_string()))
}

pub fn resolved_with<Read>(read: Read) -> Result<PathBuf, Diagnostic>
where
    Read: Fn() -> Option<String>,
{
    let path = read().unwrap_or_default();

    path.split(':')
        .filter(|held| !held.is_empty())
        .map(|held| Path::new(held).join("nix"))
        .find(|held| held.is_file())
        .ok_or_else(diagnostics::nix_absent)
}

fn spoken(arguments: &[&str]) -> Result<String, Diagnostic> {
    let client = client()?;

    let outcome = Command::new(&client)
        .args(arguments)
        .output()
        .map_err(|failure| {
            Diagnostic::new(
                diagnostics::OUTPUT_UNREADABLE,
                &["nix"],
                format!("the nix client could not be run, {failure}"),
            )
        })?;

    if !outcome.status.success() {
        return Err(Diagnostic::new(
            diagnostics::OUTPUT_UNREADABLE,
            &["nix"],
            format!(
                "nix refused {}, {}",
                arguments.join(" "),
                String::from_utf8_lossy(&outcome.stderr).trim()
            ),
        ));
    }

    Ok(String::from_utf8_lossy(&outcome.stdout).to_string())
}

fn read(source: &str, at: &[&str]) -> Result<Value, Diagnostic> {
    json::read(source).map_err(|failure| {
        Diagnostic::new(
            diagnostics::OUTPUT_UNREADABLE,
            at,
            format!("what nix wrote could not be read, {failure}"),
        )
    })
}

impl Backend for Subprocess {
    fn lock(&self, flake: &str) -> Result<Locked, Diagnostic> {
        let written = spoken(&["flake", "metadata", "--json", "--no-write-lock-file", flake])?;

        let held = read(&written, &["flake"])?;

        let tree = held
            .field("path")
            .and_then(Value::text)
            .ok_or_else(|| {
                Diagnostic::new(
                    diagnostics::OUTPUT_UNREADABLE,
                    &["flake", "path"],
                    "the lock named no tree",
                )
            })?
            .to_string();

        Ok(Locked {
            reference: flake.to_string(),
            tree,
        })
    }

    fn attrs(&self, locked: &Locked, path: &str) -> Result<Vec<String>, Diagnostic> {
        let written = spoken(&[
            "eval",
            "--json",
            "--no-write-lock-file",
            "--apply",
            "builtins.attrNames",
            &format!("{}#{path}", locked.reference),
        ])?;

        read(&written, &[path])?.names().ok_or_else(|| {
            Diagnostic::new(
                diagnostics::OUTPUT_UNREADABLE,
                &[path],
                "what sits there is no attribute set",
            )
        })
    }

    fn walk(&self, locked: &Locked, path: &str) -> Result<Value, Diagnostic> {
        let written = spoken(&[
            "eval",
            "--json",
            "--no-write-lock-file",
            &format!("{}#{path}", locked.reference),
        ])?;

        read(&written, &[path])
    }

    fn realise(&self, locked: &Locked, path: &str) -> Result<PathBuf, Diagnostic> {
        let written = spoken(&[
            "build",
            "--no-link",
            "--print-out-paths",
            "--no-write-lock-file",
            &format!("{}#{path}", locked.reference),
        ])?;

        written
            .lines()
            .next()
            .map(|held| PathBuf::from(held.trim()))
            .filter(|held| !held.as_os_str().is_empty())
            .ok_or_else(|| {
                Diagnostic::new(
                    diagnostics::OUTPUT_UNREADABLE,
                    &[path],
                    "the build named no path",
                )
            })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_absent_client_is_a_located_diagnostic() {
        let refusal = resolved_with(|| Some(String::new())).expect_err("a client was found");

        assert_eq!(refusal.code, diagnostics::NIX_ABSENT);
        assert_eq!(refusal.place(), "$.nix");
    }

    #[test]
    fn an_unset_path_is_the_same_refusal() {
        let refusal = resolved_with(|| None).expect_err("a client was found");

        assert_eq!(refusal.code, diagnostics::NIX_ABSENT);
    }

    #[test]
    fn the_client_is_read_off_the_path_and_not_baked() {
        let held = std::env::temp_dir().join(format!("lexicon-client-{}", std::process::id()));

        std::fs::create_dir_all(&held).expect("the scratch tree was refused");
        std::fs::write(held.join("nix"), "#!/bin/sh\n").expect("the client was refused");

        let found =
            resolved_with(|| Some(held.display().to_string())).expect("no client was found");

        assert_eq!(found, held.join("nix"));

        let _ = std::fs::remove_dir_all(&held);
    }
}
