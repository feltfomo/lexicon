// the tools a file is formatted by, and the order they run in
//
// the nix order was read off a traced run of treefmt 2.6.0 over deadnix
// 1.3.2, nixfmt 1.5.0 and statix through the fix wrapper it built, where
// formatters of equal priority are applied in name order. statix leaves work
// undone on a file nixfmt has not reached yet, so the order decides the bytes
// and is pinned here rather than left to whatever a caller's path offers
//
// rust files were formatted by nothing before, because the tree held no rust.
// rustfmt is new coverage rather than a tool the old configuration ran, so
// nothing about it is part of what the nix files are held to

use std::path::{Path, PathBuf};
use std::process::Command;

pub struct Tool {
    pub name: &'static str,
    pub variable: &'static str,
    pub extension: &'static str,
    pub leading: &'static [&'static str],
    pub config_variable: Option<&'static str>,
    // the wrapper treefmt built loops over its arguments and calls statix
    // once per file, and a single call over many files is a different tool
    pub per_file: bool,
}

pub const ORDER: [Tool; 4] = [
    Tool {
        name: "deadnix",
        variable: "LEXICON_DEADNIX",
        extension: "nix",
        leading: &["--edit"],
        config_variable: None,
        per_file: false,
    },
    Tool {
        name: "nixfmt",
        variable: "LEXICON_NIXFMT",
        extension: "nix",
        leading: &[],
        config_variable: None,
        per_file: false,
    },
    Tool {
        name: "statix",
        variable: "LEXICON_STATIX",
        extension: "nix",
        leading: &["fix"],
        config_variable: Some("LEXICON_STATIX_CONFIG"),
        per_file: true,
    },
    Tool {
        name: "rustfmt",
        variable: "LEXICON_RUSTFMT",
        extension: "rs",
        leading: &["--edition", "2021"],
        config_variable: None,
        per_file: false,
    },
];

// the tools are read from the environment the package wrapped the binary in,
// never from a path, so a tree formats the same way for every caller
pub fn program(tool: &Tool) -> Result<PathBuf, String> {
    match std::env::var_os(tool.variable) {
        Some(value) if !value.is_empty() => Ok(PathBuf::from(value)),
        _ => Err(format!(
            "no {} was handed to the formatter, so {} cannot be run",
            tool.variable, tool.name
        )),
    }
}

pub fn reaches(tool: &Tool, path: &Path) -> bool {
    path.extension()
        .map(|held| held == tool.extension)
        .unwrap_or(false)
}

pub fn run(tool: &Tool, files: &[PathBuf]) -> Result<(), String> {
    if files.is_empty() {
        return Ok(());
    }

    let program = program(tool)?;
    let batches: Vec<&[PathBuf]> = if tool.per_file {
        files.chunks(1).collect()
    } else {
        vec![files]
    };

    for batch in batches {
        let mut command = Command::new(&program);
        command.args(tool.leading);

        if let Some(variable) = tool.config_variable {
            if let Some(path) = std::env::var_os(variable) {
                command.arg("--config").arg(path);
            }
        }

        command.args(batch);

        let status = command
            .status()
            .map_err(|failure| format!("{} could not be run, {failure}", tool.name))?;

        if !status.success() {
            return Err(format!("{} refused the files it was given", tool.name));
        }
    }

    Ok(())
}

pub fn run_all(files: &[PathBuf]) -> Result<(), String> {
    for tool in ORDER.iter() {
        let reached: Vec<PathBuf> = files
            .iter()
            .filter(|path| reaches(tool, path))
            .cloned()
            .collect();

        run(tool, &reached)?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_nix_order_is_the_one_treefmt_applied() {
        let names: Vec<&str> = ORDER
            .iter()
            .filter(|tool| tool.extension == "nix")
            .map(|tool| tool.name)
            .collect();

        assert_eq!(names, vec!["deadnix", "nixfmt", "statix"]);
    }

    #[test]
    fn only_statix_is_called_once_per_file() {
        let per_file: Vec<&str> = ORDER
            .iter()
            .filter(|tool| tool.per_file)
            .map(|tool| tool.name)
            .collect();

        assert_eq!(per_file, vec!["statix"]);
    }

    #[test]
    fn deadnix_edits_rather_than_reports() {
        assert_eq!(ORDER[0].leading, &["--edit"]);
    }

    #[test]
    fn a_nix_tool_is_handed_no_rust_file_and_the_other_way_round() {
        let nix = PathBuf::from("held.nix");
        let rust = PathBuf::from("held.rs");

        assert!(reaches(&ORDER[0], &nix));
        assert!(!reaches(&ORDER[0], &rust));
        assert!(reaches(&ORDER[3], &rust));
        assert!(!reaches(&ORDER[3], &nix));
    }

    #[test]
    fn a_tool_with_no_path_is_refused_rather_than_searched_for() {
        let tool = Tool {
            name: "absent",
            variable: "LEXICON_A_TOOL_NOBODY_HANDED_OVER",
            extension: "nix",
            leading: &[],
            config_variable: None,
            per_file: false,
        };

        assert!(program(&tool).is_err());
    }
}
