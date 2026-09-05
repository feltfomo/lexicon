use crate::{
    model::{Result, clean, fail},
    plan::{Invocation, Plan},
    process,
};
use std::{
    collections::BTreeSet,
    fs::{self, File, OpenOptions},
    io::{self, IsTerminal, Write},
    os::{
        fd::AsRawFd,
        unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt},
    },
    path::{Component, Path},
    process::{Command, Stdio},
    time::Instant,
};

fn locks(names: &BTreeSet<String>) -> Result<Vec<File>> {
    if names.is_empty() {
        return Ok(Vec::new());
    }
    let uid = unsafe { libc::geteuid() };
    let directory = format!("/tmp/praxis-{uid}");
    match fs::DirBuilder::new().mode(0o700).create(&directory) {
        Ok(()) => (),
        Err(e) if e.kind() == io::ErrorKind::AlreadyExists => (),
        Err(e) => return Err(fail(73, e.to_string())),
    }
    let metadata = fs::symlink_metadata(&directory).map_err(|e| fail(73, e.to_string()))?;
    if !metadata.file_type().is_dir() || metadata.uid() != uid || metadata.mode() & 0o077 != 0 {
        return Err(fail(
            73,
            "lock directory must be private and owned by the current user",
        ));
    }
    names
        .iter()
        .map(|name| {
            if name.is_empty()
                || !name
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
            {
                return Err(fail(65, "invalid lock name"));
            }
            let file = OpenOptions::new()
                .read(true)
                .write(true)
                .create(true)
                .truncate(false)
                .mode(0o600)
                .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
                .open(Path::new(&directory).join(name))
                .map_err(|e| fail(73, e.to_string()))?;
            if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
                let error = io::Error::last_os_error();
                return Err(fail(
                    if error.kind() == io::ErrorKind::WouldBlock {
                        75
                    } else {
                        73
                    },
                    format!("lock {name} unavailable: {error}"),
                ));
            }
            Ok(file)
        })
        .collect()
}
fn confirmation(prompt: &str, yes: bool) -> Result<()> {
    if yes {
        return Ok(());
    }
    if !io::stdin().is_terminal() {
        return Err(fail(64, "confirmation needs a terminal or --yes"));
    }
    eprint!("{} [y/N] ", clean(prompt));
    io::stderr().flush().map_err(|e| fail(74, e.to_string()))?;
    let mut descriptor = libc::pollfd {
        fd: libc::STDIN_FILENO,
        events: libc::POLLIN,
        revents: 0,
    };
    loop {
        process::cancelled()?;
        let ready = unsafe { libc::poll(&mut descriptor, 1, 100) };
        if ready > 0 {
            break;
        }
        if ready < 0 && io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
            return Err(fail(74, io::Error::last_os_error().to_string()));
        }
    }
    let mut answer = String::new();
    io::stdin()
        .read_line(&mut answer)
        .map_err(|e| fail(74, e.to_string()))?;
    if matches!(answer.trim(), "y" | "Y" | "yes") {
        Ok(())
    } else {
        Err(fail(64, "cancelled; earlier steps were not rolled back"))
    }
}
fn child(step: &Invocation) -> Result<Command> {
    let cwd = step
        .cwd
        .canonicalize()
        .map_err(|e| fail(66, format!("working directory {}: {e}", step.cwd.display())))?;
    let mut program = std::ffi::OsString::from(&step.program);
    let mut prefix = Vec::new();
    if let Some(relative) = &step.script {
        if Path::new(relative)
            .components()
            .any(|part| !matches!(part, Component::Normal(_)))
        {
            return Err(fail(65, "script must be a clean relative path"));
        }
        let resolved = cwd
            .join(relative)
            .canonicalize()
            .map_err(|e| fail(66, format!("script not found {relative}: {e}")))?;
        if !resolved.starts_with(&cwd) {
            return Err(fail(65, "script escapes the live project root"));
        }
        if !resolved.is_file() {
            return Err(fail(66, "script is not a regular file"));
        }
        if program.is_empty() {
            if resolved
                .metadata()
                .map_err(|e| fail(66, e.to_string()))?
                .mode()
                & 0o111
                == 0
            {
                return Err(fail(
                    126,
                    "script is not executable; set interpreter or its executable bit",
                ));
            }
            program = resolved.into_os_string();
        } else {
            prefix.push(resolved.into_os_string());
        }
    }
    let mut child = Command::new(program);
    child
        .args(prefix)
        .args(&step.args)
        .current_dir(&cwd)
        .env("PWD", &cwd);
    if !step.path.is_empty() {
        let mut path = std::ffi::OsString::from(&step.path);
        if let Some(inherited) = std::env::var_os("PATH") {
            path.push(":");
            path.push(inherited);
        }
        child.env("PATH", path);
    }
    child
        .envs(step.env.iter())
        .stdin(if step.interactive {
            Stdio::inherit()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());
    Ok(child)
}
fn state(color: bool, code: &str, name: &str) -> String {
    if color {
        format!("\x1b[{code}m{name}\x1b[0m")
    } else {
        name.into()
    }
}
pub fn execute(plan: &Plan, plain: bool, yes: bool) -> Result<()> {
    process::install()?;
    let _locks = locks(&plan.locks)?;
    let color = !plain
        && io::stderr().is_terminal()
        && std::env::var_os("NO_COLOR").is_none()
        && std::env::var_os("CI").is_none()
        && std::env::var("TERM").as_deref() != Ok("dumb");
    let total = plan.steps.len();
    let started = Instant::now();
    eprintln!(
        "{} {}\n  {}\n  {total} pending",
        state(color, "1;36", "praxis"),
        clean(&plan.command),
        clean(&plan.cwd.to_string_lossy())
    );
    for (index, step) in plan.steps.iter().enumerate() {
        let number = index + 1;
        let at = Instant::now();
        eprintln!(
            "{} [{number}/{total}] {}",
            state(color, "36", "running"),
            clean(&step.label)
        );
        let result = (|| {
            process::cancelled()?;
            for prompt in &step.confirmations {
                confirmation(prompt, yes)?;
            }
            process::cancelled()?;
            let code = process::execute(&mut child(step)?, step.interactive)?;
            if code == 0 {
                Ok(())
            } else {
                Err(fail(
                    code,
                    format!("{} failed (exit {code}): {}", step.command, step.label),
                ))
            }
        })();
        if let Err(error) = result {
            eprintln!(
                "{} [{number}/{total}] {} ({:.2}s)\n  {index} succeeded, 1 failed, {} skipped; earlier effects were not rolled back",
                state(color, "31", "failed"),
                clean(&step.label),
                at.elapsed().as_secs_f64(),
                total - number
            );
            return Err(error);
        }
        eprintln!(
            "{} [{number}/{total}] {} ({:.2}s)",
            state(color, "32", "succeeded"),
            clean(&step.label),
            at.elapsed().as_secs_f64()
        );
    }
    eprintln!(
        "{total} succeeded ({:.2}s)",
        started.elapsed().as_secs_f64()
    );
    Ok(())
}
