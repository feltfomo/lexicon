use crate::model::{Command, Manifest};
use std::{collections::BTreeMap, ops::Bound};

pub enum Selection<'a> {
    Command {
        name: &'a str,
        command: &'a Command,
        consumed: usize,
    },
    Group(String),
    Unknown(String),
}

pub fn is_group(manifest: &Manifest, name: &str) -> bool {
    let prefix = format!("{name}.");
    manifest
        .commands
        .range::<str, _>((Bound::Included(prefix.as_str()), Bound::Unbounded))
        .next()
        .is_some_and(|(candidate, _)| candidate.starts_with(&prefix))
}

pub fn select<'a>(
    manifest: &'a Manifest,
    aliases: &'a BTreeMap<String, String>,
    words: &[String],
) -> Selection<'a> {
    let mut path = String::new();
    for (index, word) in words.iter().enumerate() {
        if !path.is_empty() {
            path.push('.');
        }
        path.push_str(word);
        let canonical = aliases.get(&path).map_or(path.as_str(), String::as_str);
        if let Some((name, command)) = manifest.commands.get_key_value(canonical) {
            return Selection::Command {
                name,
                command,
                consumed: index + 1,
            };
        }
        if !is_group(manifest, &path) {
            return Selection::Unknown(path.replace('.', " "));
        }
    }
    Selection::Group(path)
}

pub fn children(manifest: &Manifest, parent: &str) -> Vec<String> {
    let mut values = Vec::new();
    for (name, command) in &manifest.commands {
        if command.hidden {
            continue;
        }
        let remaining = if parent.is_empty() {
            name.as_str()
        } else {
            let Some(rest) = name
                .strip_prefix(parent)
                .and_then(|rest| rest.strip_prefix('.'))
            else {
                continue;
            };
            rest
        };
        values.push(remaining.split('.').next().unwrap_or(remaining).to_owned());
        if parent.is_empty() {
            values.extend(command.aliases.iter().cloned());
        }
    }
    values.sort();
    values.dedup();
    values
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Project;

    fn manifest() -> Manifest {
        Manifest {
            version: 2,
            name: "praxis".into(),
            bash: "bash".into(),
            project: Project {
                cwd: None,
                discover_root: None,
                require_root: false,
                expected_flake: None,
                ui: Default::default(),
            },
            commands: ["update.input", "update.all", "update-old", "echo"]
                .into_iter()
                .map(|name| (name.into(), Command::default()))
                .collect(),
        }
    }

    #[test]
    fn selects_subcommands_without_consuming_child_arguments() {
        let manifest = manifest();
        let aliases = BTreeMap::new();
        let words = ["update", "input", "lexicon", "--help"].map(String::from);
        let Selection::Command { name, consumed, .. } = select(&manifest, &aliases, &words) else {
            panic!("subcommand was not selected")
        };
        assert_eq!(name, "update.input");
        assert_eq!(&words[consumed..], &["lexicon", "--help"]);
    }

    #[test]
    fn groups_complete_children_and_reject_unknown_subcommands() {
        let manifest = manifest();
        let aliases = BTreeMap::new();
        assert!(matches!(
            select(&manifest, &aliases, &["update".into()]),
            Selection::Group(_)
        ));
        assert!(matches!(
            select(&manifest, &aliases, &["update".into(), "missing".into()]),
            Selection::Unknown(_)
        ));
        assert_eq!(children(&manifest, ""), ["echo", "update", "update-old"]);
        assert_eq!(children(&manifest, "update"), ["all", "input"]);
    }

    #[test]
    fn executable_names_cannot_hide_subcommands() {
        let mut manifest = manifest();
        manifest
            .commands
            .insert("update".into(), Command::default());
        assert!(crate::inspect::aliases(&manifest).is_err());
    }
}
