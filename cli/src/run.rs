// formatting a set of files, and answering whether formatting would change
// them without changing them
//
// the check runs the same tools over copies rather than a second reading of
// what each tool would do, because a rule that only described the tools
// would drift from them the first time one of them was bumped

use std::io;
use std::path::{Path, PathBuf};

use crate::tools;

pub fn format(files: &[PathBuf]) -> Result<(), String> {
    tools::run_all(files)
}

// the copies are flat and numbered because each tool reads one file at a
// time and nothing it does depends on where the file sat
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
        // the copies keep the shape the originals sat in, because a rust file
        // names its neighbours and a tool reading one has to find them where
        // the file says they are
        let copy = held.join(mirrored(file));

        if let Some(parent) = copy.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|failure| format!("{} could not be made, {failure}", parent.display()))?;
        }

        std::fs::copy(file, &copy)
            .map_err(|failure| format!("{} could not be read, {failure}", file.display()))?;

        // a copy carries the mode it came from, and the tools rewrite the file
        // they are handed, so a read only original has to become a writable copy
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

// the path a file takes inside the scratch tree. the root markers are
// dropped so an absolute path lands under the scratch rather than escaping it
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
