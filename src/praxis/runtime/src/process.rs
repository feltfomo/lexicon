use crate::model::{Result, fail};
use std::{
    fs::{File, OpenOptions},
    os::{
        fd::{AsRawFd, FromRawFd, OwnedFd},
        unix::process::{CommandExt, ExitStatusExt},
    },
    process::{Command, ExitStatus},
    sync::atomic::{AtomicI32, Ordering},
    thread,
    time::{Duration, Instant},
};
static SIGNAL: AtomicI32 = AtomicI32::new(0);
extern "C" fn caught(signal: i32) {
    SIGNAL.store(signal, Ordering::SeqCst);
}
pub fn install() -> Result<()> {
    // orphaned children stay with the runner until their process group is reaped.
    if unsafe { libc::prctl(libc::PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) } != 0 {
        return Err(fail(70, std::io::Error::last_os_error().to_string()));
    }
    // only the atomic signal flag is touched from the handler.
    for signal in [libc::SIGINT, libc::SIGTERM, libc::SIGHUP, libc::SIGQUIT] {
        if unsafe { libc::signal(signal, caught as *const () as libc::sighandler_t) }
            == libc::SIG_ERR
        {
            return Err(fail(70, std::io::Error::last_os_error().to_string()));
        }
    }
    Ok(())
}
pub fn cancelled() -> Result<()> {
    let signal = SIGNAL.load(Ordering::SeqCst);
    if signal == 0 {
        Ok(())
    } else {
        Err(fail(128 + signal, format!("cancelled by signal {signal}")))
    }
}
fn foreground(tty: &File, group: i32) -> std::io::Result<()> {
    // terminal ownership changes happen in the parent, outside signal handlers.
    unsafe {
        let previous = libc::signal(libc::SIGTTOU, libc::SIG_IGN);
        let result = libc::tcsetpgrp(tty.as_raw_fd(), group);
        let error = std::io::Error::last_os_error();
        libc::signal(libc::SIGTTOU, previous);
        if result == -1 { Err(error) } else { Ok(()) }
    }
}
struct Terminal {
    tty: File,
    group: i32,
}
impl Drop for Terminal {
    fn drop(&mut self) {
        let _ = foreground(&self.tty, self.group);
    }
}
fn group_signal(group: i32, signal: i32) {
    unsafe {
        libc::kill(-group, signal);
    }
}
fn status_code(status: ExitStatus) -> i32 {
    status
        .code()
        .unwrap_or_else(|| 128 + status.signal().unwrap_or(libc::SIGTERM))
}
fn exit_notification(group: i32) -> Result<Option<OwnedFd>> {
    // the child handle owns reaping; the pidfd only wakes the waiter.
    let fd = unsafe { libc::syscall(libc::SYS_pidfd_open, group, 0) };
    if fd >= 0 {
        return Ok(Some(unsafe { OwnedFd::from_raw_fd(fd as i32) }));
    }
    let error = std::io::Error::last_os_error();
    if matches!(error.raw_os_error(), Some(libc::ENOSYS | libc::EPERM)) {
        Ok(None)
    } else {
        Err(fail(70, format!("open child exit notification: {error}")))
    }
}
fn wait_for_exit(notification: Option<&OwnedFd>) -> Result<()> {
    let Some(notification) = notification else {
        thread::sleep(Duration::from_millis(20));
        return Ok(());
    };
    let mut descriptor = libc::pollfd {
        fd: notification.as_raw_fd(),
        events: libc::POLLIN,
        revents: 0,
    };
    // a signal received just before poll still needs a bounded cancellation check.
    let ready = unsafe { libc::poll(&mut descriptor, 1, 20) };
    if ready < 0 {
        let error = std::io::Error::last_os_error();
        if error.kind() != std::io::ErrorKind::Interrupted {
            return Err(fail(70, error.to_string()));
        }
    } else if descriptor.revents & (libc::POLLNVAL | libc::POLLERR) != 0 {
        return Err(fail(70, "invalid child exit notification"));
    }
    Ok(())
}
pub fn execute(command: &mut Command, interactive: bool) -> Result<i32> {
    use std::io::IsTerminal;
    cancelled()?;
    let terminal = if interactive && std::io::stdin().is_terminal() {
        let tty = OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/tty")
            .map_err(|e| fail(74, e.to_string()))?;
        let group = unsafe { libc::tcgetpgrp(tty.as_raw_fd()) };
        if group < 0 {
            return Err(fail(74, std::io::Error::last_os_error().to_string()));
        }
        Some(Terminal { tty, group })
    } else {
        None
    };
    command.process_group(0);
    let mut child = command.spawn().map_err(|e| {
        fail(
            if e.kind() == std::io::ErrorKind::NotFound {
                127
            } else {
                126
            },
            e.to_string(),
        )
    })?;
    let group = child.id() as i32;
    if let Some(terminal) = &terminal {
        if let Err(error) = foreground(&terminal.tty, group) {
            group_signal(group, libc::SIGKILL);
            let _ = child.wait();
            return Err(fail(74, error.to_string()));
        }
        group_signal(group, libc::SIGCONT);
    }
    let result = (|| {
        let notification = exit_notification(group)?;
        let mut cancelled_at = None;
        loop {
            let signal = SIGNAL.load(Ordering::SeqCst);
            if signal != 0 && cancelled_at.is_none() {
                group_signal(group, signal);
                cancelled_at = Some(Instant::now());
            }
            if cancelled_at.is_some_and(|at| at.elapsed() >= Duration::from_secs(2)) {
                group_signal(group, libc::SIGKILL);
            }
            match child.try_wait() {
                Ok(Some(status)) => break Ok(status_code(status)),
                Ok(None) => wait_for_exit(notification.as_ref())?,
                Err(error) => break Err(fail(70, error.to_string())),
            }
        }
    })();
    group_signal(group, libc::SIGTERM);
    if unsafe { libc::kill(-group, 0) } == 0 {
        thread::sleep(Duration::from_millis(100));
        group_signal(group, libc::SIGKILL);
    }
    let _ = child.wait();
    drop(terminal);
    let deadline = Instant::now() + Duration::from_secs(2);
    loop {
        let reaped = unsafe { libc::waitpid(-group, std::ptr::null_mut(), libc::WNOHANG) };
        if reaped > 0 {
            continue;
        }
        if reaped < 0 && std::io::Error::last_os_error().raw_os_error() == Some(libc::ECHILD) {
            break;
        }
        if Instant::now() >= deadline {
            return Err(fail(70, "child process group did not finish cleanup"));
        }
        thread::sleep(Duration::from_millis(10));
    }
    cancelled()?;
    result
}
