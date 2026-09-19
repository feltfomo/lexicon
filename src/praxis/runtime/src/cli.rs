use crate::{
    completion, inspect,
    model::{Manifest, Result, fail},
    plan, run,
    ui::{self, Options},
};

pub fn dispatch(manifest: &Manifest, args: Vec<String>) -> Result<()> {
    let mut options = Options::default();
    let result = dispatch_inner(manifest, &args, &mut options);
    if let Err(error) = &result
        && options
            .ui
            .output
            .as_deref()
            .map_or(options.json_errors, |mode| mode == "json")
    {
        ui::json(&serde_json::json!({"event":"error","code":error.code,"message":error.message}))?;
    }
    result
}
fn dispatch_inner(manifest: &Manifest, args: &[String], options: &mut Options) -> Result<()> {
    options.json_errors = manifest.project.ui.mode() == "json";
    let mut index = 0;
    while index < args.len() && args[index].starts_with('-') && args[index] != "--version" {
        if !options.take(args, &mut index)? {
            return Err(fail(64, "unknown runner option"));
        }
        index += 1;
    }
    options.json_errors = manifest.project.ui.overlay(&options.ui).mode() == "json";
    let aliases = inspect::aliases(manifest)?;
    let Some(action) = args.get(index).map(String::as_str) else {
        return usage(&manifest.name);
    };
    // built-ins keep their namespace; run also reaches commands named after them
    let (action, args) =
        if ui::ACTIONS.contains(&action) || matches!(action, "complete" | "--version") {
            (action, &args[index + 1..])
        } else {
            ("run", &args[index..])
        };
    if action == "complete" {
        let words = args.strip_prefix(&["--".into()]).unwrap_or(args);
        return ui::output(
            &completion::candidates(manifest, &aliases, words)
                .iter()
                .map(|v| format!("{v}\n"))
                .collect::<String>(),
        );
    }
    match action {
        "help" if args.is_empty() => usage(&manifest.name),
        "--version" => ui::output(&format!(
            "{} {}\n",
            manifest.name,
            env!("CARGO_PKG_VERSION")
        )),
        "list" => {
            options.take_all(args)?;
            inspect::list(
                manifest,
                options.all,
                &manifest.project.ui.overlay(&options.ui),
            )
        }
        "completions" => match args {
            [shell] => completion::generate(manifest, shell, false),
            [shell, flag] if flag == "--wrappers" => completion::generate(manifest, shell, true),
            _ => Err(fail(
                64,
                format!(
                    "usage: {} completions fish|bash|zsh [--wrappers]",
                    manifest.name
                ),
            )),
        },
        "run" | "plan" | "show" | "doctor" | "help" => {
            if action == "doctor" && (args.is_empty() || args[0].starts_with('-')) {
                options.take_all(args)?;
                let config = manifest.project.ui.overlay(&options.ui);
                options.json_errors = config.mode() == "json";
                let mut failed = false;
                for (name, command) in &manifest.commands {
                    if command.hidden && !options.all {
                        continue;
                    }
                    if let Err(error) = inspect::doctor(manifest, name, &[], &config) {
                        failed = true;
                        if config.mode() == "json" {
                            ui::json(
                                &serde_json::json!({"command":name,"ok":false,"message":error.message}),
                            )?;
                        } else {
                            eprintln!(
                                "{}: {}",
                                crate::model::clean(name),
                                crate::model::clean(&error.message)
                            );
                        }
                    }
                }
                return if failed {
                    Err(fail(1, "doctor found unavailable runtime requirements"))
                } else {
                    Ok(())
                };
            }
            let requested = args
                .first()
                .ok_or_else(|| fail(64, format!("{action} needs a command name")))?;
            let name = aliases.get(requested).unwrap_or(requested);
            let command = manifest
                .commands
                .get(name)
                .ok_or_else(|| fail(64, format!("unknown command {requested}")))?;
            // inspection and execution bind exactly the same command arguments
            let command_args = args[1..].to_vec();
            let config = manifest
                .project
                .ui
                .overlay(&command.ui)
                .overlay(&options.ui);
            options.json_errors = config.mode() == "json";
            if matches!(action, "show" | "help") && !command_args.is_empty() && !options.help {
                return Err(fail(64, format!("{action} takes no runtime arguments")));
            }
            if options.help || matches!(action, "show" | "help") {
                return inspect::help(&manifest.name, name, command, &config);
            }
            if action == "doctor" {
                return inspect::doctor(manifest, name, &command_args, &config);
            }
            let mut plan = plan::build(manifest, name, &command_args)?;
            plan.ui = config.clone();
            for step in &mut plan.steps {
                step.ui = step.ui.overlay(&options.ui);
            }
            options.json_errors |= plan.steps.iter().any(|s| s.ui.mode() == "json");
            if action == "plan" {
                inspect::show_plan(&plan, &config)
            } else {
                run::execute(&plan, options)
            }
        }
        _ => Err(fail(
            64,
            "expected list, show, plan, run, doctor or completions",
        )),
    }
}
fn usage(prefix: &str) -> Result<()> {
    ui::output(&format!(
        "Praxis runs your declared commands.\n\n  {prefix} [RUNNER OPTIONS] NAME [ARGS...]\n  {prefix} list [--all] [--json]\n  {prefix} help [NAME]\n  {prefix} show NAME\n  {prefix} [--plain|--json] plan NAME [ARGS...]\n  {prefix} doctor [NAME [ARGS]]\n  {prefix} completions fish|bash|zsh [--wrappers]\n\nRunner options go before NAME: --yes, --non-interactive, --quiet, --verbose,\n--plain, --json, --color MODE, --no-progress, --notify WHEN, --bell.\nEverything after NAME belongs to the command, including --help and --.\nUse '{prefix} run NAME' for a command named after a built-in.\n"
    ))
}
