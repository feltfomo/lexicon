use crate::{
    model::{Result, clean, fail},
    plan::{Invocation, Plan},
    process,
};
use std::{
    collections::BTreeSet,
    fs::{self, File, OpenOptions},
    io,
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
            // keep lock inodes stable so contenders cannot acquire different files
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
pub fn child(step: &Invocation) -> Result<Command> {
    let cwd = step
        .cwd
        .canonicalize()
        .map_err(|e| fail(66, format!("working directory {}: {e}", step.cwd.display())))?;
    if !cwd.is_dir() {
        return Err(fail(66, "working directory is not a directory"));
    }
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
fn eligible(step: &Invocation, answers: &std::collections::BTreeMap<String, String>) -> bool {
    step.conditions.iter().all(|c| {
        c.parameters_match
            && (c.platforms.is_empty()
                || c.platforms.iter().any(|p| {
                    p == std::env::consts::OS
                        || p.strip_prefix(std::env::consts::ARCH)
                            .and_then(|s| s.strip_prefix('-'))
                            == Some(std::env::consts::OS)
                }))
            && c.env.iter().all(|(key, expected)| {
                if let Some(actual) = answers.get(key).or_else(|| step.env.get(key)) {
                    expected.as_deref() == Some(actual.as_str())
                } else {
                    // non-unicode environment values are present, not absent
                    std::env::var_os(key).as_deref()
                        == expected.as_deref().map(std::ffi::OsStr::new)
                }
            })
    })
}
pub fn execute(plan: &Plan, options: &crate::ui::Options) -> Result<()> {
    use crate::{interaction, model::Prompt, notify, ui};
    use std::{collections::BTreeMap, time::Duration};
    process::install()?;
    let started = Instant::now();
    let root_deadline = plan.timeout.map(|s| started + Duration::from_secs(s));
    let mut config = plan.ui.overlay(&options.ui);
    let json = config.mode() == "json"
        || plan
            .steps
            .iter()
            .any(|s| s.ui.overlay(&options.ui).mode() == "json");
    if json {
        config.output = Some("json".into());
    }
    let mut policy = options.policy;
    policy.non_interactive |= json;
    let _locks = locks(&plan.locks)?;
    let total = plan.steps.len();
    let mut succeeded = 0;
    let mut skipped = 0;
    let mut failed = 0;
    let mut answers = BTreeMap::new();
    let mut budgets = BTreeMap::new();
    let mut secrets: BTreeMap<(Option<String>, String), String> = BTreeMap::new();
    for (name, notice) in &plan.notices {
        if json {
            ui::json(&serde_json::json!({"event":"deprecated", "command":name,"message":notice}))?;
        } else {
            eprintln!("praxis: {} is deprecated: {}", clean(name), clean(notice));
        }
    }
    ui::event(
        &config,
        "started",
        &plan.command,
        &plan.command,
        0,
        total,
        0.0,
    )?;
    let result = (|| {
        for (index, step) in plan.steps.iter().enumerate() {
            interaction::deadline(root_deadline)?;
            let mut config = step.ui.overlay(&options.ui);
            if json {
                config.output = Some("json".into());
            }
            if !eligible(step, &answers) {
                skipped += 1;
                ui::event(
                    &config,
                    "skipped",
                    &step.command,
                    &step.label,
                    index + 1,
                    total,
                    0.0,
                )?;
                continue;
            }
            let at = Instant::now();
            let mut deadline = root_deadline;
            for budget in &step.budgets {
                let end = *budgets
                    .entry(budget.id)
                    .or_insert_with(|| at + Duration::from_secs(budget.seconds));
                deadline = Some(deadline.map_or(end, |d| d.min(end)));
            }
            if let Some(seconds) = step.timeout {
                let end = at + Duration::from_secs(seconds);
                deadline = Some(deadline.map_or(end, |d| d.min(end)));
            }
            ui::event(
                &config,
                "running",
                &step.command,
                &step.label,
                index + 1,
                total,
                0.0,
            )?;
            let result = (|| {
                interaction::deadline(deadline)?;
                if step.interactive && (policy.non_interactive || std::env::var_os("CI").is_some())
                {
                    return Err(fail(
                        64,
                        "interactive step is disabled in non-interactive execution",
                    ));
                }
                for message in &step.confirmations {
                    interaction::ask(
                        &Prompt {
                            kind: "confirm".into(),
                            message: message.clone(),
                            name: None,
                            acknowledgement: None,
                            choices: vec![],
                            default: None,
                        },
                        policy,
                        deadline,
                    )?;
                }
                if let Some(prompt) = &step.prompt {
                    let value = interaction::ask(prompt, policy, deadline)?;
                    if let Some(name) = &prompt.name {
                        answers.insert(
                            format!(
                                "PRAXIS_PROMPT_{}",
                                name.replace('-', "_").to_ascii_uppercase()
                            ),
                            value,
                        );
                    }
                    return Ok(());
                }
                let mut child = child(step)?;
                child.envs(&answers);
                // inherited sources never escape into an unrelated or unmasked child
                for key in &plan.sensitive_env {
                    child.env_remove(key);
                }
                for (key, secret) in step.secrets.iter() {
                    let cache_key = (secret.source.clone(), secret.name.clone());
                    let value = match secrets.entry(cache_key) {
                        std::collections::btree_map::Entry::Occupied(entry) => entry.into_mut(),
                        std::collections::btree_map::Entry::Vacant(entry) => {
                            let value = match secret.source.as_ref().map(std::env::var).transpose()
                            {
                                Ok(Some(value)) => value,
                                Ok(None) | Err(std::env::VarError::NotPresent) => {
                                    if !secret.required && policy.unattended() {
                                        String::new()
                                    } else {
                                        interaction::secret(
                                            &format!("{}:", secret.name),
                                            policy,
                                            deadline,
                                        )?
                                    }
                                }
                                Err(_) => {
                                    return Err(fail(
                                        64,
                                        "sensitive environment input must be UTF-8",
                                    ));
                                }
                            };
                            entry.insert(value)
                        }
                    };
                    // each binding enforces requiredness, including a cached optional value
                    if secret.required && value.is_empty() {
                        return Err(fail(64, "required sensitive input is empty"));
                    }
                    child.env(key, value.as_str());
                }
                // secret-bearing children have no output channel into runner logs
                if !step.secrets.is_empty() {
                    child.stdout(Stdio::null()).stderr(Stdio::null());
                } else if json {
                    child.stdout(Stdio::from(io::stderr()));
                }
                if config.mode() == "verbose" {
                    eprintln!(
                        "  cwd={} program={} argv={}{}",
                        clean(&step.cwd.to_string_lossy()),
                        clean(&step.program),
                        step.args.len(),
                        if step.secrets.is_empty() {
                            ""
                        } else {
                            " [sensitive output suppressed]"
                        }
                    );
                }
                let code = process::execute(&mut child, step.interactive, deadline)?;
                if code == 0 {
                    Ok(())
                } else {
                    Err(fail(
                        code,
                        format!("{} failed (exit {code}): {}", step.command, step.label),
                    ))
                }
            })();
            if result.is_ok() {
                succeeded += 1;
            } else {
                failed += 1;
            }
            ui::event(
                &config,
                if result.is_ok() {
                    "succeeded"
                } else {
                    "failed"
                },
                &step.command,
                &step.label,
                index + 1,
                total,
                at.elapsed().as_secs_f64(),
            )?;
            if step.notify {
                let _ = notify::send(
                    &config,
                    &step.label,
                    result.is_ok(),
                    &step.cwd,
                    &plan.sensitive_env,
                );
            }
            result?;
        }
        Ok(())
    })();
    let not_run = total.saturating_sub(succeeded + skipped + failed);
    if json {
        ui::json(
            &serde_json::json!({"event":"finished","command":plan.command,"total":total,"succeeded":succeeded,"skipped":skipped,"failed":failed,"not_run":not_run,"success":result.is_ok(),"code":result.as_ref().err().map_or(0, |e: &crate::model::Failure| e.code),"seconds":started.elapsed().as_secs_f64()}),
        )?;
    } else if config.mode() != "quiet" && config.progress != Some(false) {
        eprintln!(
            "{succeeded} succeeded, {skipped} skipped, {failed} failed, {not_run} not run ({:.2}s){}",
            started.elapsed().as_secs_f64(),
            if result.is_err() {
                "; earlier effects were not rolled back"
            } else {
                ""
            }
        );
    }
    let _ = notify::send(
        &config,
        &plan.command,
        result.is_ok(),
        &plan.cwd,
        &plan.sensitive_env,
    );
    result
}
