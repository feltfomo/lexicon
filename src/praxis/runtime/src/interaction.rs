use crate::{
    model::{Prompt, Result, clean, fail},
    process,
};
use std::{
    io::{self, IsTerminal, Write},
    time::Instant,
};

#[derive(Clone, Copy, Default)]
pub struct Policy {
    pub yes: bool,
    pub non_interactive: bool,
}
impl Policy {
    pub fn unattended(self) -> bool {
        self.non_interactive
            || std::env::var_os("CI").is_some()
            || !io::stdin().is_terminal()
            || !io::stderr().is_terminal()
    }
}
struct Echo(libc::termios);
impl Echo {
    fn hide() -> Result<Self> {
        let mut saved = std::mem::MaybeUninit::uninit();
        if unsafe { libc::tcgetattr(libc::STDIN_FILENO, saved.as_mut_ptr()) } != 0 {
            return Err(fail(74, "cannot read terminal settings"));
        }
        let saved = unsafe { saved.assume_init() };
        let mut hidden = saved;
        hidden.c_lflag &= !(libc::ECHO | libc::ECHONL);
        if unsafe { libc::tcsetattr(libc::STDIN_FILENO, libc::TCSANOW, &hidden) } != 0 {
            return Err(fail(74, "cannot disable terminal echo"));
        }
        Ok(Self(saved))
    }
}
impl Drop for Echo {
    fn drop(&mut self) {
        // discard unfinished secret input before echo returns to the caller
        while unsafe { libc::tcsetattr(libc::STDIN_FILENO, libc::TCSAFLUSH, &self.0) } != 0 {
            if io::Error::last_os_error().kind() != io::ErrorKind::Interrupted {
                break;
            }
        }
    }
}
pub fn deadline(at: Option<Instant>) -> Result<()> {
    process::cancelled()?;
    if at.is_some_and(|at| Instant::now() >= at) {
        Err(fail(124, "timeout expired"))
    } else {
        Ok(())
    }
}
fn line(message: &str, hidden: bool, at: Option<Instant>) -> Result<String> {
    deadline(at)?;
    // echo is disabled before the prompt becomes visible
    let _echo = if hidden { Some(Echo::hide()?) } else { None };
    eprint!("{} ", clean(message));
    io::stderr().flush().map_err(|e| fail(74, e.to_string()))?;
    let mut answer = Vec::new();
    loop {
        deadline(at)?;
        let mut fd = libc::pollfd {
            fd: libc::STDIN_FILENO,
            events: libc::POLLIN,
            revents: 0,
        };
        let ready = unsafe { libc::poll(&mut fd, 1, 50) };
        if ready < 0 {
            let error = io::Error::last_os_error();
            if error.kind() == io::ErrorKind::Interrupted {
                continue;
            }
            return Err(fail(74, "cannot read terminal input"));
        }
        if ready == 0 {
            continue;
        }
        let mut byte = 0u8;
        let read = unsafe { libc::read(libc::STDIN_FILENO, (&mut byte as *mut u8).cast(), 1) };
        if read == 0 {
            return Err(fail(64, "prompt input ended"));
        }
        if read < 0 {
            if io::Error::last_os_error().kind() == io::ErrorKind::Interrupted {
                continue;
            }
            return Err(fail(74, "cannot read terminal input"));
        }
        if byte == b'\n' {
            break;
        }
        if answer.len() >= 65536 {
            return Err(fail(64, "prompt input is too long"));
        }
        answer.push(byte);
    }
    if hidden {
        eprintln!();
    }
    if answer.last() == Some(&b'\r') {
        answer.pop();
    }
    String::from_utf8(answer).map_err(|_| fail(64, "prompt input must be UTF-8"))
}
pub fn secret(message: &str, policy: Policy, at: Option<Instant>) -> Result<String> {
    if policy.unattended() {
        return Err(fail(
            64,
            "sensitive input needs its environment source or a terminal",
        ));
    }
    line(message, true, at)
}
pub fn ask(prompt: &Prompt, policy: Policy, at: Option<Instant>) -> Result<String> {
    deadline(at)?;
    if prompt.kind == "confirm" && policy.yes {
        return Ok("true".into());
    }
    if policy.unattended() || (policy.yes && prompt.kind == "select") {
        if prompt.kind == "select"
            && let Some(value) = &prompt.default
        {
            return Ok(value.clone());
        }
        return Err(fail(
            64,
            format!(
                "{} prompt requires a terminal{}",
                prompt.kind,
                if prompt.kind == "confirm" {
                    " or --yes"
                } else {
                    ""
                }
            ),
        ));
    }
    let message = match prompt.kind.as_str() {
        "confirm" => format!(
            "{} {}",
            prompt.message,
            if prompt.default.as_deref() == Some("true") {
                "[Y/n]"
            } else {
                "[y/N]"
            }
        ),
        "acknowledge" => format!(
            "{} [type {}]",
            prompt.message,
            prompt.acknowledgement.as_deref().unwrap_or("")
        ),
        "select" => {
            for (index, choice) in prompt.choices.iter().enumerate() {
                eprintln!("  {}. {}", index + 1, clean(choice));
            }
            format!(
                "{}{}",
                prompt.message,
                prompt
                    .default
                    .as_ref()
                    .map_or(String::new(), |v| format!(" [default {}]", clean(v)))
            )
        }
        _ => return Err(fail(65, "unknown prompt type")),
    };
    let answer = line(&message, false, at)?;
    match prompt.kind.as_str() {
        "confirm" => {
            let value = if answer.is_empty() {
                prompt.default.as_deref().unwrap_or("false")
            } else {
                answer.trim()
            };
            if matches!(value, "y" | "Y" | "yes" | "true") {
                Ok("true".into())
            } else {
                Err(fail(64, "declined; earlier steps were not rolled back"))
            }
        }
        "acknowledge" if prompt.acknowledgement.as_deref() == Some(&answer) => Ok(answer),
        "acknowledge" => Err(fail(64, "acknowledgement did not match")),
        "select" => {
            let value = if answer.is_empty() {
                prompt.default.clone()
            } else if prompt.choices.contains(&answer) {
                Some(answer)
            } else {
                answer
                    .parse::<usize>()
                    .ok()
                    .and_then(|n| n.checked_sub(1))
                    .and_then(|n| prompt.choices.get(n).cloned())
            };
            value.ok_or_else(|| fail(64, "selection did not match a choice"))
        }
        _ => Err(fail(65, "unknown prompt type")),
    }
}
