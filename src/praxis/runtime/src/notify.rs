use crate::{
    model::{Result, Ui},
    process, ui,
};
use std::{
    io::{self, IsTerminal, Write},
    process::{Command, Stdio},
    time::{Duration, Instant},
};

pub fn send(
    config: &Ui,
    name: &str,
    success: bool,
    cwd: &std::path::Path,
    sensitive_env: &std::collections::BTreeSet<String>,
) -> Result<()> {
    let Some(options) = &config.notifications else {
        return Ok(());
    };
    if !(if success {
        options.success.unwrap_or(true)
    } else {
        options.failure.unwrap_or(true)
    }) {
        return Ok(());
    }
    if options.bell == Some(true)
        && io::stderr().is_terminal()
        && config.mode() != "json"
        && std::env::var_os("CI").is_none()
    {
        let _ = io::stderr().write_all(b"\x07");
    }
    if options.desktop != Some(true) {
        return Ok(());
    }
    let fallback = vec!["notify-send".to_owned()];
    let argv = options.command.as_ref().unwrap_or(&fallback);
    let Some((program, args)) = argv.split_first() else {
        return Ok(());
    };
    let status = if success { "succeeded" } else { "failed" };
    let mut child = Command::new(program);
    child
        .args(args)
        .arg("Praxis")
        .arg(format!("{} {status}", crate::model::clean(name)))
        .current_dir(cwd)
        .env_clear()
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    // notifications receive display access, never the command's credentials
    for key in [
        "PATH",
        "HOME",
        "DISPLAY",
        "WAYLAND_DISPLAY",
        "XDG_RUNTIME_DIR",
        "DBUS_SESSION_BUS_ADDRESS",
    ] {
        if !sensitive_env.contains(key)
            && let Some(value) = std::env::var_os(key)
        {
            child.env(key, value);
        }
    }
    let delivered = matches!(
        process::execute(
            &mut child,
            false,
            Some(Instant::now() + Duration::from_secs(3))
        ),
        Ok(0)
    );
    if !delivered {
        if config.mode() == "json" {
            ui::json(&serde_json::json!({"event":"notification_failed","command":name}))?;
        } else if config.mode() != "quiet" {
            eprintln!("praxis: desktop notification unavailable");
        }
    }
    Ok(())
}
