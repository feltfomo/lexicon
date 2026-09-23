// default formatting follows git's tracked files, while named paths bypass
// repository selection.

use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::tools;

// keep these exclusions aligned with the former treefmt selection.
pub const EXCLUDES: &[&str] = &[
    "docs/*",
    "LICENSE",
    "*.lock",
    "*.patch",
    "package-lock.json",
    "go.mod",
    "go.sum",
    ".gitattributes",
    ".gitignore",
    ".gitmodules",
    ".hgignore",
    ".svnignore",
];

// `*` and `?` stay within one path segment.
pub fn glob_matches(pattern: &str, path: &str) -> bool {
    let pattern: Vec<char> = pattern.chars().collect();
    let path: Vec<char> = path.chars().collect();

    fn walk(pattern: &[char], path: &[char]) -> bool {
        match pattern.first() {
            None => path.is_empty(),
            Some('*') => {
                if walk(&pattern[1..], path) {
                    return true;
                }

                match path.first() {
                    Some(&held) if held != '/' => walk(pattern, &path[1..]),
                    _ => false,
                }
            }
            Some('?') => match path.first() {
                Some(&held) if held != '/' => walk(&pattern[1..], &path[1..]),
                _ => false,
            },
            Some(&held) => match path.first() {
                Some(&seen) if seen == held => walk(&pattern[1..], &path[1..]),
                _ => false,
            },
        }
    }

    walk(&pattern, &path)
}

pub fn excluded(relative: &str) -> bool {
    EXCLUDES
        .iter()
        .any(|pattern| glob_matches(pattern, relative))
}

pub fn formattable(path: &Path) -> bool {
    tools::ORDER.iter().any(|tool| tools::reaches(tool, path))
}

// without git, walk the tree so formatting still has a deterministic input.
pub fn tracked(root: &Path) -> io::Result<Vec<PathBuf>> {
    let asked = Command::new("git")
        .arg("-C")
        .arg(root)
        .args(["ls-files", "-z", "--cached"])
        .output();

    match asked {
        Ok(answer) if answer.status.success() => Ok(String::from_utf8_lossy(&answer.stdout)
            .split('\0')
            .filter(|held| !held.is_empty())
            .map(PathBuf::from)
            .collect()),
        _ => walked(root, Path::new("")),
    }
}

fn walked(root: &Path, under: &Path) -> io::Result<Vec<PathBuf>> {
    let mut found = Vec::new();

    for entry in std::fs::read_dir(root.join(under))? {
        let entry = entry?;
        let named = under.join(entry.file_name());

        if entry.file_name() == ".git" {
            continue;
        }

        if entry.file_type()?.is_dir() {
            found.extend(walked(root, &named)?);
        } else {
            found.push(named);
        }
    }

    Ok(found)
}

// directory selection uses the lister's relative paths; named files bypass it.
pub fn select_with<Lister>(requested: &[PathBuf], lister: Lister) -> io::Result<Vec<PathBuf>>
where
    Lister: Fn(&Path) -> io::Result<Vec<PathBuf>>,
{
    let asked: Vec<PathBuf> = if requested.is_empty() {
        vec![PathBuf::from(".")]
    } else {
        requested.to_vec()
    };

    let mut found: Vec<PathBuf> = Vec::new();

    for path in asked {
        if path.is_dir() {
            for relative in lister(&path)? {
                let named = path.join(&relative);

                // skip paths that git lists but the working tree no longer has.
                if formattable(&named) && !excluded(&relative.to_string_lossy()) && named.is_file()
                {
                    found.push(named);
                }
            }
        } else if formattable(&path) {
            found.push(path);
        }
    }

    found.sort();
    found.dedup();

    Ok(found)
}

pub fn select(requested: &[PathBuf]) -> io::Result<Vec<PathBuf>> {
    select_with(requested, tracked)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> PathBuf {
        let root =
            std::env::temp_dir().join(format!("lexicon-select-{name}-{}", std::process::id()));

        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).expect("the scratch tree could not be made");

        root
    }

    fn written(root: &Path, name: &str) {
        let path = root.join(name);

        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).expect("the scratch tree could not be made");
        }

        std::fs::write(path, "{ }\n").expect("the scratch file could not be written");
    }

    #[test]
    fn a_star_does_not_reach_across_a_directory() {
        assert!(glob_matches("docs/*", "docs/held.md"));
        assert!(!glob_matches("docs/*", "docs/under/held.md"));
        assert!(glob_matches("*.lock", "Cargo.lock"));
        assert!(!glob_matches("*.lock", "cli/Cargo.lock"));
    }

    #[test]
    fn the_kinds_reached_are_the_kinds_a_tool_formats() {
        assert!(formattable(Path::new("held.nix")));
        assert!(formattable(Path::new("held.rs")));
        assert!(!formattable(Path::new("held.md")));
        assert!(!formattable(Path::new("held")));
    }

    #[test]
    fn a_directory_is_what_the_lister_tracks() {
        let root = scratch("tracked");

        written(&root, "tracked.nix");
        written(&root, "untracked.nix");
        written(&root, "tracked.md");

        let found = select_with(std::slice::from_ref(&root), |_| {
            Ok(vec![
                PathBuf::from("tracked.nix"),
                PathBuf::from("tracked.md"),
            ])
        })
        .expect("the selection failed");

        assert_eq!(found, vec![root.join("tracked.nix")]);
    }

    #[test]
    fn a_named_file_is_formatted_whether_it_is_tracked_or_not() {
        let root = scratch("named");

        written(&root, "untracked.nix");

        let found = select_with(&[root.join("untracked.nix")], |_| Ok(Vec::new()))
            .expect("the selection failed");

        assert_eq!(found, vec![root.join("untracked.nix")]);
    }

    #[test]
    fn named_paths_are_the_only_paths_reached() {
        let root = scratch("named-only");

        written(&root, "one.nix");
        written(&root, "two.nix");

        let found = select_with(&[root.join("one.nix")], |_| {
            Ok(vec![PathBuf::from("one.nix"), PathBuf::from("two.nix")])
        })
        .expect("the selection failed");

        assert_eq!(found, vec![root.join("one.nix")]);
    }

    #[test]
    fn an_excluded_file_is_left_alone_when_the_tree_is_walked() {
        let root = scratch("excluded");

        written(&root, "docs/held.nix");
        written(&root, "kept.nix");

        let found = select_with(std::slice::from_ref(&root), |_| {
            Ok(vec![
                PathBuf::from("docs/held.nix"),
                PathBuf::from("kept.nix"),
            ])
        })
        .expect("the selection failed");

        assert_eq!(found, vec![root.join("kept.nix")]);
    }
}
