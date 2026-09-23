// writing and checking use the same tools so their byte output stays in step.

use std::io;
use std::path::{Path, PathBuf};

use crate::tools;

pub fn format(files: &[PathBuf]) -> Result<(), String> {
    tools::run_all(files)
}

pub fn would_change(files: &[PathBuf]) -> Result<Vec<PathBuf>, String> {
    if files.is_empty() {
        return Ok(Vec::new());
    }

    let held = scratch().map_err(|failure| format!("no scratch tree could be made, {failure}"))?;

    let outcome = compared(files, &held);

    let _ = std::fs::remove_dir_all(&held);

    outcome
}

fn compared(files: &[PathBuf], held: &Path) -> Result<Vec<PathBuf>, String> {
    let mut copies = Vec::new();

    for file in files.iter() {
        // tools may read neighbouring files relative to the copy, so preserve
        // each input's path inside the scratch tree.
        let copy = held.join(mirrored(file));

        if let Some(parent) = copy.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|failure| format!("{} could not be made, {failure}", parent.display()))?;
        }

        std::fs::copy(file, &copy)
            .map_err(|failure| format!("{} could not be read, {failure}", file.display()))?;

        // formatters need writable copies even when the original is read-only.
        writable(&copy)
            .map_err(|failure| format!("{} could not be written, {failure}", copy.display()))?;

        copies.push(copy);
    }

    tools::run_all(&copies)?;

    let mut changed = Vec::new();

    for (file, copy) in files.iter().zip(copies.iter()) {
        let before = std::fs::read(file)
            .map_err(|failure| format!("{} could not be read, {failure}", file.display()))?;
        let after = std::fs::read(copy)
            .map_err(|failure| format!("{} could not be read, {failure}", copy.display()))?;

        if before != after {
            changed.push(file.clone());
        }
    }

    Ok(changed)
}

// mirror absolute inputs under scratch without letting them escape it.
fn mirrored(path: &Path) -> PathBuf {
    use std::path::Component;

    let mut held = PathBuf::new();

    for part in path.components() {
        match part {
            Component::Normal(name) => held.push(name),
            Component::ParentDir => held.push("up"),
            _ => {}
        }
    }

    held
}

fn writable(path: &Path) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o644))
}

fn scratch() -> io::Result<PathBuf> {
    let root = std::env::temp_dir().join(format!("lexicon-fmt-{}", std::process::id()));

    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root)?;

    Ok(root)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nothing_to_format_changes_nothing() {
        let changed: Vec<PathBuf> = would_change(&[]).expect("the check failed");

        assert!(changed.is_empty());
    }
}
