use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(untagged)]
pub enum Argument {
    Text(String),
    Parameter { param: String },
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Parameter {
    pub name: String,
    pub description: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub positional: bool,
    pub required: bool,
    pub default: Option<String>,
    #[serde(default)]
    pub choices: Vec<String>,
    #[serde(default)]
    pub env: Option<String>,
    #[serde(default)]
    pub short: Option<char>,
    #[serde(default)]
    pub sensitive: bool,
}
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Ui {
    pub output: Option<String>,
    pub color: Option<String>,
    pub progress: Option<bool>,
    pub notifications: Option<Notifications>,
}
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Notifications {
    pub success: Option<bool>,
    pub failure: Option<bool>,
    pub bell: Option<bool>,
    pub desktop: Option<bool>,
    pub command: Option<Vec<String>>,
}
impl Ui {
    pub fn overlay(&self, other: &Self) -> Self {
        let mut value = self.clone();
        if other.output.is_some() {
            value.output.clone_from(&other.output);
        }
        if other.color.is_some() {
            value.color.clone_from(&other.color);
        }
        if other.progress.is_some() {
            value.progress = other.progress;
        }
        if let Some(next) = &other.notifications {
            let target = value
                .notifications
                .get_or_insert_with(Notifications::default);
            if next.success.is_some() {
                target.success = next.success;
            }
            if next.failure.is_some() {
                target.failure = next.failure;
            }
            if next.bell.is_some() {
                target.bell = next.bell;
            }
            if next.desktop.is_some() {
                target.desktop = next.desktop;
            }
            if next.command.is_some() {
                target.command.clone_from(&next.command);
            }
        }
        value
    }
    pub fn mode(&self) -> &str {
        self.output.as_deref().unwrap_or("concise")
    }
}
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct Condition {
    pub parameters: BTreeMap<String, String>,
    pub platforms: Vec<String>,
    pub env: BTreeMap<String, Option<String>>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Prompt {
    #[serde(rename = "type")]
    pub kind: String,
    pub message: String,
    pub name: Option<String>,
    pub acknowledgement: Option<String>,
    #[serde(default)]
    pub choices: Vec<String>,
    pub default: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ParameterGroup {
    #[serde(rename = "type")]
    pub kind: String,
    pub parameters: Vec<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Action {
    Run {
        run: String,
    },
    Exec {
        exec: Vec<Argument>,
    },
    Script {
        script: String,
        interpreter: Option<String>,
        #[serde(default, rename = "rootRelative")]
        root_relative: bool,
    },
    Command {
        command: String,
    },
    Prompt {
        prompt: Prompt,
    },
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Step {
    #[serde(flatten)]
    pub action: Action,
    pub args: Vec<Argument>,
    pub label: String,
    pub cwd: Option<String>,
    pub env: BTreeMap<String, String>,
    pub interactive: bool,
    pub confirm: Option<String>,
    pub forward_args: bool,
    #[serde(default)]
    pub when: Condition,
    #[serde(default)]
    pub timeout: Option<u64>,
    #[serde(default)]
    pub ui: Ui,
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum CommandScope {
    #[default]
    Project,
    Global,
}
impl CommandScope {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Project => "project",
            Self::Global => "global",
        }
    }
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum CommandKind {
    #[default]
    Command,
    Task,
}
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Command {
    pub description: String,
    #[serde(default)]
    pub kind: CommandKind,
    #[serde(default)]
    pub scope: CommandScope,
    pub steps: Vec<Step>,
    pub parameters: Vec<Parameter>,
    pub cwd: Option<String>,
    pub env: BTreeMap<String, String>,
    pub path: String,
    pub lock: Option<String>,
    #[serde(default)]
    pub timeout: Option<u64>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub aliases: Vec<String>,
    #[serde(default)]
    pub examples: Vec<String>,
    #[serde(default)]
    pub hidden: bool,
    #[serde(default)]
    pub deprecated: Option<String>,
    #[serde(default)]
    pub parameter_groups: Vec<ParameterGroup>,
    #[serde(default)]
    pub ui: Ui,
}
impl Command {
    pub fn forwarding(&self) -> bool {
        self.steps.iter().any(|step| step.forward_args)
    }
}
#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Project {
    pub cwd: Option<String>,
    pub discover_root: Option<String>,
    pub require_root: bool,
    pub expected_flake: Option<String>,
    #[serde(default)]
    pub ui: Ui,
}
fn dispatcher_name() -> String {
    "praxis".into()
}
#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub version: u32,
    #[serde(default = "dispatcher_name")]
    pub name: String,
    pub bash: String,
    pub project: Project,
    pub commands: BTreeMap<String, Command>,
}
#[derive(Debug)]
pub struct Failure {
    pub code: i32,
    pub message: String,
}
pub type Result<T> = std::result::Result<T, Failure>;
pub fn fail(code: i32, message: impl Into<String>) -> Failure {
    Failure {
        code,
        message: message.into(),
    }
}
pub fn clean(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        if c.is_control() {
            out.extend(c.escape_default());
        } else {
            out.push(c);
        }
    }
    out
}
