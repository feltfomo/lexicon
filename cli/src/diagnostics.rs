use std::fmt;

// TODO keep shadow text here while built-in names live in rust. move it to
// the commands block if flake declarations own the built-in table.
pub const COMMAND_SHADOWS_BUILTIN: &str = "telos/command-shadows-builtin";

pub const NIX_ABSENT: &str = "lexicon/nix-absent";

pub const OUTPUT_UNREADABLE: &str = "lexicon/output-unreadable";

pub const COMMAND_UNKNOWN: &str = "lexicon/command-unknown";

pub const COMMAND_MALFORMED: &str = "lexicon/command-malformed";

pub const CHECK_REFUSED: &str = "lexicon/check-refused";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Diagnostic {
    pub code: &'static str,
    pub at: Vec<String>,
    pub message: String,
    pub help: Option<String>,
}

impl Diagnostic {
    pub fn new(code: &'static str, at: &[&str], message: impl Into<String>) -> Self {
        Diagnostic {
            code,
            at: at.iter().map(|one| (*one).to_string()).collect(),
            message: message.into(),
            help: None,
        }
    }

    pub fn helped(mut self, help: impl Into<String>) -> Self {
        self.help = Some(help.into());

        self
    }

    pub fn place(&self) -> String {
        self.at.iter().fold(String::from("$"), |held, one| {
            if one
                .chars()
                .all(|seen| seen.is_alphanumeric() || seen == '-' || seen == '_')
            {
                format!("{held}.{one}")
            } else {
                format!("{held}.\"{one}\"")
            }
        })
    }
}

impl fmt::Display for Diagnostic {
    fn fmt(&self, into: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            into,
            "{} at {}\n  {}",
            self.code,
            self.place(),
            self.message
        )?;

        match &self.help {
            Some(help) => write!(into, "\n  {help}"),
            None => Ok(()),
        }
    }
}

pub fn nix_absent() -> Diagnostic {
    Diagnostic::new(
        NIX_ABSENT,
        &["nix"],
        "nix is not on the path, so the flake cannot be read",
    )
    .helped("install nix, or run this from a shell where the client is on the path")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_place_is_written_the_way_lexicon_writes_one() {
        let held = Diagnostic::new(COMMAND_SHADOWS_BUILTIN, &["commands", "check"], "shadowed");

        assert_eq!(held.place(), "$.commands.check");
    }

    #[test]
    fn a_name_that_is_no_plain_word_is_quoted() {
        let held = Diagnostic::new(COMMAND_UNKNOWN, &["apps", "a name"], "unknown");

        assert_eq!(held.place(), "$.apps.\"a name\"");
    }

    #[test]
    fn a_diagnostic_renders_its_code_place_message_and_help() {
        let held = nix_absent();

        let shown = held.to_string();

        assert!(shown.starts_with("lexicon/nix-absent at $.nix\n"));
        assert!(shown.contains("install nix"));
    }
}
