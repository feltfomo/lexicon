use crate::{
    model::{Action, Command, Manifest, Result, Ui, clean, fail},
    plan::{self, Plan},
    run, ui,
};
use std::{collections::BTreeMap, os::unix::fs::PermissionsExt, path::Path};

fn validate_ui(ui: &Ui) -> Result<()> {
    if !ui::OUTPUT_MODES.contains(&ui.mode())
        || ui
            .color
            .as_deref()
            .is_some_and(|c| !ui::COLOR_MODES.contains(&c))
    {
        return Err(fail(65, "invalid UI configuration"));
    }
    if ui
        .notifications
        .as_ref()
        .and_then(|n| n.command.as_ref())
        .is_some_and(|a| a.first().is_none_or(String::is_empty))
    {
        return Err(fail(65, "notification command needs an executable"));
    }
    Ok(())
}
pub fn aliases(manifest: &Manifest) -> Result<BTreeMap<String, String>> {
    validate_ui(&manifest.project.ui)?;
    let mut aliases = BTreeMap::new();
    let sensitive_env = plan::sensitive_environment(manifest);
    let protected = |name: &str| sensitive_env.contains(name);
    let valid_name = |value: &str| {
        value
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_alphanumeric)
            && value
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, b'-' | b'_'))
    };
    if !valid_name(&manifest.name) {
        return Err(fail(65, "invalid dispatcher name"));
    }
    for (name, command) in &manifest.commands {
        if !valid_name(name)
            || name == &manifest.name
            || command
                .aliases
                .iter()
                .any(|a| !valid_name(a) || a == &manifest.name)
        {
            return Err(fail(65, "invalid command name or alias"));
        }
        validate_ui(&command.ui)?;
        if command
            .steps
            .iter()
            .filter(|step| step.forward_args)
            .count()
            > 1
        {
            return Err(fail(
                65,
                "at most one step may receive pass-through arguments",
            ));
        }
        if command
            .timeout
            .into_iter()
            .chain(command.steps.iter().filter_map(|s| s.timeout))
            .any(|s| !(1..=604800).contains(&s))
        {
            return Err(fail(
                65,
                "timeout must be positive seconds, at most one week",
            ));
        }
        for step in &command.steps {
            validate_ui(&step.ui)?;
        }
        for alias in &command.aliases {
            if manifest.commands.contains_key(alias)
                || aliases.insert(alias.clone(), name.clone()).is_some()
            {
                return Err(fail(
                    65,
                    "command aliases must be unique and cannot shadow names",
                ));
            }
        }
        if command.env.keys().any(|key| protected(key)) {
            return Err(fail(65, "sensitive environment cannot be overridden"));
        }
        for parameter in &command.parameters {
            if parameter.sensitive
                && (parameter.default.is_some()
                    || !parameter.choices.is_empty()
                    || parameter.positional
                    || parameter.kind != "string")
            {
                return Err(fail(
                    65,
                    "sensitive parameters cannot contain defaults or choices",
                ));
            }
            if !parameter.sensitive
                && (protected(&crate::arguments::env_key(&parameter.name))
                    || parameter.env.as_deref().is_some_and(protected))
            {
                return Err(fail(
                    65,
                    "sensitive environment cannot feed an ordinary parameter",
                ));
            }
        }
        let sensitive: std::collections::BTreeSet<_> = command
            .parameters
            .iter()
            .filter(|p| p.sensitive)
            .map(|p| p.name.as_str())
            .collect();
        if command
            .parameter_groups
            .iter()
            .any(|g| g.parameters.iter().any(|p| sensitive.contains(p.as_str())))
        {
            return Err(fail(65, "sensitive parameters cannot enter groups"));
        }
        for step in &command.steps {
            if step
                .env
                .keys()
                .chain(step.when.env.keys())
                .any(|key| protected(key))
                || step
                    .when
                    .parameters
                    .keys()
                    .any(|p| sensitive.contains(p.as_str()))
            {
                return Err(fail(
                    65,
                    "sensitive environment cannot be overridden or inspected by conditions",
                ));
            }
            if let Action::Prompt { prompt } = &step.action
                && prompt.name.as_ref().is_some_and(|name| {
                    protected(&format!(
                        "PRAXIS_PROMPT_{}",
                        name.replace('-', "_").to_ascii_uppercase()
                    ))
                })
            {
                return Err(fail(
                    65,
                    "prompt responses cannot replace sensitive environment",
                ));
            }
            if let Action::Prompt { prompt } = &step.action {
                let valid = match prompt.kind.as_str() {
                    "confirm" => prompt
                        .default
                        .as_deref()
                        .is_none_or(|v| matches!(v, "true" | "false")),
                    "acknowledge" => {
                        prompt
                            .acknowledgement
                            .as_ref()
                            .is_some_and(|s| !s.is_empty())
                            && prompt.default.is_none()
                    }
                    "select" => {
                        !prompt.choices.is_empty()
                            && prompt.name.is_some()
                            && prompt
                                .default
                                .as_ref()
                                .is_none_or(|v| prompt.choices.contains(v))
                    }
                    _ => false,
                };
                if !valid {
                    return Err(fail(65, "invalid prompt declaration"));
                }
            }
            let args = step.args.iter().chain(match &step.action {
                Action::Exec { exec } => exec.as_slice(),
                _ => &[],
            });
            for arg in args {
                if let crate::model::Argument::Parameter { param } = arg
                    && sensitive.contains(param.as_str())
                {
                    return Err(fail(65, "sensitive parameters cannot enter argv"));
                }
            }
        }
    }
    Ok(aliases)
}
pub fn help(prefix: &str, name: &str, command: &Command, config: &Ui) -> Result<()> {
    if config.mode() == "json" {
        return ui::json(&serde_json::json!({"command": name, "declaration": command}));
    }
    let mut text = format!(
        "{}\n\nUsage: {} {}",
        clean(if command.description.is_empty() {
            name
        } else {
            &command.description
        }),
        clean(prefix),
        clean(name)
    );
    for p in command.parameters.iter().filter(|p| !p.sensitive) {
        text.push_str(&format!(
            " {}{}{}",
            if p.required { "<" } else { "[" },
            if p.positional {
                p.name.clone()
            } else {
                format!(
                    "--{}{}",
                    p.name,
                    if p.kind == "bool" { "" } else { " VALUE" }
                )
            },
            if p.required { ">" } else { "]" }
        ));
    }
    if command.forwarding() {
        text.push_str(" [ARGS...]");
    }
    text.push_str(&format!(
        "\n\nRunner options go before {name}; use '{prefix} help' to list them.\n"
    ));
    for p in &command.parameters {
        text.push_str(&format!(
            "\n  {}{} ({})  {}",
            p.name,
            p.short.map_or(String::new(), |s| format!(", -{s}")),
            p.kind,
            clean(&p.description)
        ));
        if p.sensitive {
            text.push_str(" [sensitive; runtime input only]");
        } else {
            if let Some(default) = &p.default {
                text.push_str(&format!(" [default: {}]", clean(default)));
            }
            if !p.choices.is_empty() {
                text.push_str(&format!(" [choices: {}]", clean(&p.choices.join(", "))));
            }
        }
        if let Some(env) = &p.env {
            text.push_str(&format!(" [env: {}]", clean(env)));
        }
    }
    text.push_str(&format!("\n\nScope: {}", command.scope.as_str()));
    if let Some(step) = command.steps.iter().find(|step| step.forward_args) {
        text.push_str(&format!(
            "\nArguments: remaining argv -> {}",
            clean(&step.label)
        ));
    }
    if let Some(category) = &command.category {
        text.push_str(&format!("\n\nCategory: {}", clean(category)));
    }
    if !command.aliases.is_empty() {
        text.push_str(&format!(
            "\nAliases: {}",
            clean(&command.aliases.join(", "))
        ));
    }
    if let Some(notice) = &command.deprecated {
        text.push_str(&format!("\nDeprecated: {}", clean(notice)));
    }
    if let Some(lock) = &command.lock {
        text.push_str(&format!("\nLock: {}", clean(lock)));
    }
    if let Some(timeout) = command.timeout {
        text.push_str(&format!("\nTimeout: {timeout}s"));
    }
    for group in &command.parameter_groups {
        text.push_str(&format!(
            "\n{}: {}",
            group.kind,
            group.parameters.join(", ")
        ));
    }
    text.push_str(if command.kind == crate::model::CommandKind::Task {
        "\n\nActions:\n"
    } else {
        "\n\nCommand:\n"
    });
    for step in &command.steps {
        text.push_str(&format!("  {}", clean(&step.label)));
        match &step.action {
            Action::Command { command } => text.push_str(&format!(" -> {}", clean(command))),
            Action::Prompt { prompt } => text.push_str(&format!(" [prompt: {}]", prompt.kind)),
            _ => (),
        }
        if step.confirm.is_some() {
            text.push_str(" [confirmation]");
        }
        if let Some(seconds) = step.timeout {
            text.push_str(&format!(" [timeout: {seconds}s]"));
        }
        if !step.when.parameters.is_empty()
            || !step.when.env.is_empty()
            || !step.when.platforms.is_empty()
        {
            text.push_str(" [conditional]");
        }
        text.push('\n');
    }
    if !command.examples.is_empty() {
        text.push_str("\nExamples:\n");
        for example in &command.examples {
            text.push_str(&format!("  {}\n", clean(example)));
        }
    }
    ui::output(&text)
}
pub fn list(manifest: &Manifest, all: bool, config: &Ui) -> Result<()> {
    let commands: BTreeMap<_, _> = manifest
        .commands
        .iter()
        .filter(|(_, c)| all || !c.hidden)
        .collect();
    if config.mode() == "json" {
        return ui::json(&commands);
    }
    let mut text = String::new();
    for (name, c) in commands {
        text.push_str(&format!(
            "{}\t{}{}{}{}\n",
            clean(name),
            if c.kind == crate::model::CommandKind::Task {
                "[task] "
            } else {
                ""
            },
            c.category
                .as_ref()
                .map_or(String::new(), |v| format!("[{}] ", clean(v))),
            clean(&c.description),
            if c.deprecated.is_some() {
                " [deprecated]"
            } else {
                ""
            }
        ));
        if config.mode() == "verbose" {
            text.push_str(&format!(
                "  {} steps, {} parameters; aliases: {}; lock: {}\n",
                c.steps.len(),
                c.parameters.len(),
                c.aliases.join(", "),
                c.lock.as_deref().unwrap_or("none")
            ));
        }
    }
    ui::output(&text)
}
fn execution_preview(step: &plan::Invocation) -> (String, Vec<String>) {
    let mut program = step.program.clone();
    let mut args = step.args.clone();
    if let Some(script) = &step.script {
        let path = step
            .script_root
            .as_deref()
            .unwrap_or(&step.cwd)
            .join(script)
            .to_string_lossy()
            .into_owned();
        if program.is_empty() {
            program = path;
        } else {
            args.insert(0, path);
        }
    }
    (program, args)
}
pub fn show_plan(plan: &Plan, config: &Ui) -> Result<()> {
    // inspection materializes script argv without reading or freezing live contents
    if config.output.is_none() || config.mode() == "json" {
        let mut value = serde_json::to_value(plan).map_err(|e| fail(70, e.to_string()))?;
        value["environmentPolicy"] = serde_json::json!(
            "inherit; set PWD to cwd; prepend package PATH; apply declared overrides and prompt answers; remove protected sensitive names; bind sensitive targets only during execution"
        );
        let steps = value["steps"]
            .as_array_mut()
            .ok_or_else(|| fail(70, "invalid serialized plan"))?;
        for (value, step) in steps.iter_mut().zip(&plan.steps) {
            let (program, args) = execution_preview(step);
            value["program"] = serde_json::json!(program);
            value["args"] = serde_json::json!(args);
            if step.script.is_some() {
                value["scriptResolution"] =
                    serde_json::json!("canonicalize and validate confinement at execution");
            }
        }
        return ui::json(&value);
    }
    let mut text = format!(
        "{}\n  scope: {}\n  cwd: {}\n  locks: {}\n  environment: inherited except protected sensitive sources; declared overrides win\n  PATH: declared package prefix then inherited PATH, unless env.PATH overrides it\n",
        clean(&plan.command),
        plan.scope.as_str(),
        clean(&plan.cwd.to_string_lossy()),
        plan.locks.iter().cloned().collect::<Vec<_>>().join(", ")
    );
    if let Some(seconds) = plan.timeout {
        text.push_str(&format!("  command timeout: {seconds}s\n"));
    }
    for binding in &plan.bindings {
        if !binding.parameters.is_empty() {
            text.push_str(&format!(
                "  parameters [{}]: {}\n",
                clean(&binding.command),
                binding
                    .parameters
                    .iter()
                    .map(|(key, value)| format!("{}={:?}", clean(key), value))
                    .collect::<Vec<_>>()
                    .join(", ")
            ));
        }
    }
    for (index, step) in plan.steps.iter().enumerate() {
        text.push_str(&format!(
            "  {}. {} [{}]\n",
            index + 1,
            clean(&step.label),
            clean(&step.references.join(" -> "))
        ));
        if let Some(prompt) = &step.prompt {
            text.push_str(&format!(
                "     prompt: {} - {}\n",
                prompt.kind,
                clean(&prompt.message)
            ));
        }
        for message in &step.confirmations {
            text.push_str(&format!("     confirmation: {}\n", clean(message)));
        }
        for condition in &step.conditions {
            text.push_str(&format!(
                "     when: parameters {}; platforms [{}]; env {}\n",
                if condition.parameters_match {
                    "match"
                } else {
                    "do not match"
                },
                clean(&condition.platforms.join(", ")),
                clean(&format!("{:?}", condition.env))
            ));
        }
        if let Some(seconds) = step.timeout {
            text.push_str(&format!("     step timeout: {seconds}s\n"));
        }
        if !step.budgets.is_empty() {
            text.push_str(&format!(
                "     shared timeout budgets: {}\n",
                step.budgets
                    .iter()
                    .map(|b| format!("{}s", b.seconds))
                    .collect::<Vec<_>>()
                    .join(", ")
            ));
        }
        if !step.secrets.is_empty() {
            text.push_str(&format!(
                "     {} sensitive runtime inputs; child output suppressed\n",
                step.secrets.len()
            ));
        }
        if step.prompt.is_none() {
            let (program, args) = execution_preview(step);
            text.push_str(&format!(
                "     cwd: {}\n     program: {:?}\n     argv: {:?}\n     env overrides: {:?}\n     PATH prefix: {:?} (unless overridden by env.PATH)\n",
                clean(&step.cwd.to_string_lossy()), program, args, step.env, step.path
            ));
            if let Some(script) = &step.script {
                let base = step.script_root.as_deref().unwrap_or(&step.cwd);
                text.push_str(&format!(
                    "     live script: {:?} under {:?} (validated at execution)\n",
                    script, base
                ));
            }
        }
    }
    ui::output(&text)
}
pub fn doctor(manifest: &Manifest, name: &str, args: &[String], config: &Ui) -> Result<()> {
    let plan = plan::build(manifest, name, args)?;
    let mut checks = vec![serde_json::json!({"kind":"root", "label":plan.cwd, "ok":true})];
    let mut ok = true;
    for step in &plan.steps {
        if step.prompt.is_some() {
            continue;
        }
        let result = run::child(step).and_then(|child| {
            let program = Path::new(child.get_program());
            let executable = |p: &Path| {
                p.is_file()
                    && p.metadata()
                        .is_ok_and(|m| m.permissions().mode() & 0o111 != 0)
            };
            let found = if program.components().count() > 1 || program.is_absolute() {
                executable(&step.cwd.join(program))
            } else {
                let path = child
                    .get_envs()
                    .find(|(k, _)| *k == "PATH")
                    .and_then(|(_, v)| v.map(|s| s.to_owned()))
                    .or_else(|| std::env::var_os("PATH"))
                    .unwrap_or_default();
                std::env::split_paths(&path)
                    .any(|dir| executable(&step.cwd.join(dir).join(program)))
            };
            if found {
                Ok(())
            } else {
                Err(fail(127, "executable not found or not executable"))
            }
        });
        ok &= result.is_ok();
        checks.push(serde_json::json!({"kind":"step", "label":step.label, "ok":result.is_ok(), "message":result.err().map(|e| e.message)}));
    }
    if config.mode() == "json" {
        ui::json(&checks)?;
    } else {
        for check in checks {
            ui::output(&format!(
                "{} {}{}\n",
                if check["ok"] == true { "ok" } else { "fail" },
                clean(check["label"].as_str().unwrap_or("")),
                check["message"]
                    .as_str()
                    .map_or(String::new(), |s| format!(": {}", clean(s)))
            ))?;
        }
    }
    if ok {
        Ok(())
    } else {
        Err(fail(1, "doctor found unavailable runtime requirements"))
    }
}
