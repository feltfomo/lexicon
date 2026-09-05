use crate::arguments;
use crate::model::{Action, Manifest, Prompt, Result, Ui, fail};
use serde::Serialize;
use std::{
    collections::{BTreeMap, BTreeSet},
    path::{Path, PathBuf},
    rc::Rc,
};

#[derive(Serialize)]
pub struct Invocation {
    pub command: String,
    pub label: String,
    pub cwd: PathBuf,
    pub program: String,
    pub args: Vec<String>,
    pub script: Option<String>,
    pub env: Rc<BTreeMap<String, String>>,
    pub path: String,
    pub interactive: bool,
    pub confirmations: Vec<String>,
    pub prompt: Option<Prompt>,
    pub conditions: Vec<BoundCondition>,
    pub budgets: Vec<Budget>,
    pub timeout: Option<u64>,
    pub secrets: Rc<BTreeMap<String, Secret>>,
    pub references: Vec<String>,
    pub ui: Ui,
    pub notify: bool,
}
#[derive(Clone, Serialize)]
pub struct Budget {
    pub id: usize,
    pub seconds: u64,
}
#[derive(Clone, Serialize)]
pub struct Secret {
    pub name: String,
    pub source: Option<String>,
    pub required: bool,
}
#[derive(Clone, Serialize)]
pub struct BoundCondition {
    pub parameters_match: bool,
    pub platforms: Vec<String>,
    pub env: BTreeMap<String, Option<String>>,
}
#[derive(Serialize)]
pub struct Binding {
    pub command: String,
    pub parameters: BTreeMap<String, String>,
}
#[derive(Serialize)]
pub struct Plan {
    pub command: String,
    pub cwd: PathBuf,
    pub steps: Vec<Invocation>,
    pub locks: BTreeSet<String>,
    pub bindings: Vec<Binding>,
    pub ui: Ui,
    pub timeout: Option<u64>,
    pub notices: BTreeMap<String, String>,
    #[serde(skip)]
    pub sensitive_env: BTreeSet<String>,
}
pub fn sensitive_environment(manifest: &Manifest) -> BTreeSet<String> {
    manifest
        .commands
        .values()
        .flat_map(|command| command.parameters.iter().filter(|p| p.sensitive))
        .flat_map(|p| std::iter::once(arguments::env_key(&p.name)).chain(p.env.clone()))
        .collect()
}
fn directory(base: &Path, value: Option<&str>) -> PathBuf {
    value.map_or_else(|| base.to_path_buf(), |value| base.join(value))
}
fn root(manifest: &Manifest, caller: &Path) -> Result<PathBuf> {
    let project = &manifest.project;
    let root = if let Some(marker) = &project.discover_root {
        caller
            .ancestors()
            .find(|path| path.join(marker).is_file())
            .ok_or_else(|| fail(64, format!("no parent contains {marker}")))?
            .to_path_buf()
    } else {
        directory(caller, project.cwd.as_deref())
    };
    let root = root
        .canonicalize()
        .map_err(|e| fail(64, format!("working directory {}: {e}", root.display())))?;
    if project.require_root {
        if root != caller || root.starts_with("/nix/store") {
            return Err(fail(64, "invoke from the live project root"));
        }
        let marker = root.join("flake.nix");
        let metadata = marker.symlink_metadata().map_err(|e| {
            fail(
                64,
                format!("project root containing flake.nix required: {e}"),
            )
        })?;
        if !metadata.file_type().is_file() {
            return Err(fail(64, "flake.nix must be a regular file, not a symlink"));
        }
        let actual = std::fs::read(&marker).map_err(|e| fail(64, e.to_string()))?;
        if project
            .expected_flake
            .as_ref()
            .is_none_or(|expected| expected.as_bytes() != actual)
        {
            return Err(fail(
                64,
                "different flake.nix; rebuild this command from the matching checkout",
            ));
        }
    }
    Ok(root)
}
struct Scope {
    cwd: PathBuf,
    env: Rc<BTreeMap<String, String>>,
    path: String,
    confirmations: Vec<String>,
    conditions: Vec<BoundCondition>,
    budgets: Vec<Budget>,
    secrets: Rc<BTreeMap<String, Secret>>,
    ui: Ui,
}
struct Builder<'a> {
    manifest: &'a Manifest,
    plan: Plan,
    stack: Vec<String>,
    next_budget: usize,
}
impl Builder<'_> {
    fn expand(&mut self, name: &str, args: &[String], parent: &Scope) -> Result<()> {
        if self.stack.iter().any(|item| item == name) {
            return Err(fail(
                65,
                format!("command cycle: {} -> {name}", self.stack.join(" -> ")),
            ));
        }
        let command = self
            .manifest
            .commands
            .get(name)
            .ok_or_else(|| fail(64, format!("unknown command {name}")))?;
        let parsed = arguments::parse(
            &command.parameters,
            args,
            command.steps.iter().any(|s| s.forward_args),
        )?;
        arguments::groups(&command.parameter_groups, &parsed.supplied)?;
        self.plan.bindings.push(Binding {
            command: name.into(),
            parameters: parsed
                .values
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
        });
        if let Some(notice) = &command.deprecated {
            self.plan.notices.insert(name.into(), notice.clone());
        }
        let ui = parent.ui.overlay(&command.ui);
        // one invocation shares a budget across its leaves, not later invocations
        let mut budgets = parent.budgets.clone();
        if let Some(seconds) = command.timeout {
            budgets.push(Budget {
                id: self.next_budget,
                seconds,
            });
            self.next_budget += 1;
        }
        let mut secrets = Rc::clone(&parent.secrets);
        for parameter in &command.parameters {
            let key = arguments::env_key(&parameter.name);
            if parameter.sensitive {
                Rc::make_mut(&mut secrets).insert(
                    key,
                    Secret {
                        name: parameter.name.clone(),
                        source: parameter.env.clone(),
                        required: parameter.required,
                    },
                );
            } else if secrets.contains_key(&key) {
                Rc::make_mut(&mut secrets).remove(&key);
            }
        }
        let cwd = directory(&parent.cwd, command.cwd.as_deref());
        // steps without overrides share their enclosing environment
        let mut env = Rc::clone(&parent.env);
        if !command.env.is_empty() || !parsed.values.is_empty() {
            let target = Rc::make_mut(&mut env);
            target.extend(
                command
                    .env
                    .iter()
                    .map(|(key, value)| (key.clone(), value.clone())),
            );
            target.extend(
                parsed
                    .values
                    .iter()
                    .map(|(key, value)| (arguments::env_key(key), value.to_string())),
            );
        }
        let path = if command.path.is_empty() {
            parent.path.clone()
        } else if parent.path.is_empty() {
            command.path.clone()
        } else {
            format!("{}:{}", command.path, parent.path)
        };
        if let Some(lock) = &command.lock {
            self.plan.locks.insert(lock.clone());
        }
        self.stack.push(name.to_owned());
        for step in &command.steps {
            let mut conditions = parent.conditions.clone();
            if !step.when.parameters.is_empty()
                || !step.when.platforms.is_empty()
                || !step.when.env.is_empty()
            {
                conditions.push(BoundCondition {
                    parameters_match: step.when.parameters.iter().all(|(k, v)| {
                        parsed
                            .values
                            .get(k.as_str())
                            .is_some_and(|actual| actual.as_ref() == v)
                    }),
                    platforms: step.when.platforms.clone(),
                    env: step.when.env.clone(),
                });
            }
            let step_ui = ui.overlay(&step.ui);
            let mut step_budgets = budgets.clone();
            if matches!(step.action, Action::Command { .. })
                && let Some(seconds) = step.timeout
            {
                step_budgets.push(Budget {
                    id: self.next_budget,
                    seconds,
                });
                self.next_budget += 1;
            }
            let mut args = arguments::resolve(&step.args, &parsed.values)?;
            if step.forward_args && !parsed.rest.is_empty() {
                if matches!(step.action, Action::Command { .. }) {
                    args.push("--".into());
                }
                args.extend_from_slice(parsed.rest);
            }
            let cwd = directory(&cwd, step.cwd.as_deref());
            let mut env = Rc::clone(&env);
            if !step.env.is_empty() {
                Rc::make_mut(&mut env).extend(
                    step.env
                        .iter()
                        .map(|(key, value)| (key.clone(), value.clone())),
                );
            }
            let mut confirmations = parent.confirmations.clone();
            if let Some(prompt) = &step.confirm {
                confirmations.push(prompt.clone());
            }
            if let Action::Command { command } = &step.action {
                self.expand(
                    command,
                    &args,
                    &Scope {
                        cwd,
                        env,
                        path: path.clone(),
                        confirmations,
                        conditions,
                        budgets: step_budgets,
                        secrets: Rc::clone(&secrets),
                        ui: step_ui,
                    },
                )?;
                continue;
            }
            let (program, mut prefix, script) = match &step.action {
                Action::Run { run } => (
                    self.manifest.bash.clone(),
                    vec![
                        "--noprofile".into(),
                        "--norc".into(),
                        "-euo".into(),
                        "pipefail".into(),
                        "-c".into(),
                        run.clone(),
                        format!("praxis:{name}"),
                    ],
                    None,
                ),
                Action::Exec { exec } => {
                    let (program, argv) =
                        exec.split_first().ok_or_else(|| fail(65, "empty exec"))?;
                    (
                        arguments::resolve_argument(program, &parsed.values)?,
                        arguments::resolve(argv, &parsed.values)?,
                        None,
                    )
                }
                Action::Script {
                    script,
                    interpreter,
                } => (
                    interpreter.clone().unwrap_or_default(),
                    vec![],
                    Some(script.clone()),
                ),
                Action::Prompt { .. } => (String::new(), vec![], None),
                Action::Command { .. } => unreachable!(),
            };
            prefix.extend(args);
            self.plan.steps.push(Invocation {
                command: name.into(),
                label: step.label.clone(),
                cwd,
                program,
                args: prefix,
                script,
                env,
                path: path.clone(),
                interactive: step.interactive,
                confirmations,
                prompt: if let Action::Prompt { prompt } = &step.action {
                    Some(prompt.clone())
                } else {
                    None
                },
                conditions,
                budgets: step_budgets,
                timeout: step.timeout,
                secrets: Rc::clone(&secrets),
                references: self.stack.clone(),
                ui: step_ui,
                notify: step.ui.notifications.is_some(),
            });
        }
        self.stack.pop();
        Ok(())
    }
}
pub fn build(manifest: &Manifest, name: &str, args: &[String]) -> Result<Plan> {
    let caller = std::env::current_dir()
        .and_then(|p| p.canonicalize())
        .map_err(|e| fail(64, e.to_string()))?;
    let cwd = root(manifest, &caller)?;
    let scope = Scope {
        cwd: cwd.clone(),
        env: Rc::new(BTreeMap::new()),
        path: String::new(),
        confirmations: Vec::new(),
        conditions: vec![],
        budgets: vec![],
        secrets: Rc::new(BTreeMap::new()),
        ui: manifest.project.ui.clone(),
    };
    let mut builder = Builder {
        manifest,
        plan: Plan {
            command: name.into(),
            cwd,
            steps: vec![],
            locks: BTreeSet::new(),
            bindings: vec![],
            ui: manifest.project.ui.overlay(
                &manifest
                    .commands
                    .get(name)
                    .ok_or_else(|| fail(64, "unknown command"))?
                    .ui,
            ),
            timeout: manifest.commands.get(name).and_then(|c| c.timeout),
            notices: BTreeMap::new(),
            sensitive_env: sensitive_environment(manifest),
        },
        next_budget: 0,
        stack: vec![],
    };
    builder.expand(name, args, &scope)?;
    Ok(builder.plan)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Argument, Command, Parameter, Project, Step};

    fn step() -> Step {
        Step {
            action: Action::Exec {
                exec: vec![
                    Argument::Text("printf".into()),
                    Argument::Parameter {
                        param: "tag".into(),
                    },
                ],
            },
            args: vec![],
            label: "print".into(),
            cwd: None,
            env: BTreeMap::new(),
            interactive: false,
            confirm: None,
            forward_args: false,
            when: Default::default(),
            timeout: None,
            ui: Ui::default(),
        }
    }
    fn command(tag: &str, steps: Vec<Step>) -> Command {
        Command {
            description: String::new(),
            steps,
            parameters: vec![Parameter {
                name: "tag".into(),
                description: String::new(),
                kind: "string".into(),
                positional: false,
                required: false,
                default: Some(tag.into()),
                choices: vec![],
                env: None,
                short: None,
                sensitive: false,
            }],
            cwd: None,
            env: BTreeMap::new(),
            path: String::new(),
            lock: None,
            ..Command::default()
        }
    }
    #[test]
    fn scope_overrides_do_not_leak_to_siblings() {
        let mut override_step = step();
        override_step.env.insert("VALUE".into(), "step".into());
        let reference = Step {
            action: Action::Command {
                command: "child".into(),
            },
            cwd: Some("nested".into()),
            env: BTreeMap::from([
                ("EXTRA".into(), "reference".into()),
                ("VALUE".into(), "reference".into()),
            ]),
            confirm: Some("Continue?".into()),
            ..step()
        };
        let mut root = command("root", vec![step(), override_step, reference, step()]);
        root.env.insert("VALUE".into(), "root".into());
        root.path = "/root/bin".into();
        root.lock = Some("outer".into());
        let mut child_override = step();
        child_override
            .env
            .insert("PRAXIS_ARG_TAG".into(), "step-tag".into());
        let mut child = command("child", vec![step(), child_override]);
        child.env.insert("VALUE".into(), "child".into());
        child.cwd = Some("child".into());
        child.path = "/child/bin".into();
        child.lock = Some("inner".into());
        let manifest = Manifest {
            version: 1,
            bash: "/bin/sh".into(),
            project: Project {
                cwd: None,
                discover_root: None,
                require_root: false,
                expected_flake: None,
                ui: Ui::default(),
            },
            commands: BTreeMap::from([("root".into(), root), ("child".into(), child)]),
        };
        let plan = build(&manifest, "root", &[]).unwrap();
        assert_eq!(plan.steps.len(), 5);
        assert_eq!(plan.steps[0].env["VALUE"], "root");
        assert_eq!(plan.steps[1].env["VALUE"], "step");
        assert_eq!(plan.steps[2].env["VALUE"], "child");
        assert_eq!(plan.steps[2].env["EXTRA"], "reference");
        assert_eq!(plan.steps[2].env["PRAXIS_ARG_TAG"], "child");
        assert_eq!(plan.steps[3].env["PRAXIS_ARG_TAG"], "step-tag");
        assert_eq!(plan.steps[3].args, ["child"]);
        assert_eq!(plan.steps[4].env["PRAXIS_ARG_TAG"], "root");
        assert!(!plan.steps[4].env.contains_key("EXTRA"));
        assert!(Rc::ptr_eq(&plan.steps[0].env, &plan.steps[4].env));
        assert!(!Rc::ptr_eq(&plan.steps[0].env, &plan.steps[1].env));
        assert_eq!(plan.steps[2].cwd, plan.cwd.join("nested/child"));
        assert_eq!(plan.steps[2].path, "/child/bin:/root/bin");
        assert_eq!(plan.steps[4].path, "/root/bin");
        assert_eq!(plan.steps[2].confirmations, ["Continue?"]);
        assert_eq!(plan.steps[3].confirmations, ["Continue?"]);
        assert!(plan.steps[4].confirmations.is_empty());
        assert_eq!(
            plan.locks.into_iter().collect::<Vec<_>>(),
            ["inner", "outer"]
        );
    }
}
