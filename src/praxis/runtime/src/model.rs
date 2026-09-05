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
    },
    Command {
        command: String,
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
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Command {
    pub description: String,
    pub steps: Vec<Step>,
    pub parameters: Vec<Parameter>,
    pub cwd: Option<String>,
    pub env: BTreeMap<String, String>,
    pub path: String,
    pub lock: Option<String>,
}
#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Project {
    pub cwd: Option<String>,
    pub discover_root: Option<String>,
    pub require_root: bool,
    pub expected_flake: Option<String>,
}
#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub version: u32,
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
