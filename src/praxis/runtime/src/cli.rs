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
        && (options.ui.mode() == "json" || options.json_errors)
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
        return usage();
    };
    let args = &args[index + 1..];
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
        "help" => usage(),
        "--version" => ui::output(concat!("praxis ", env!("CARGO_PKG_VERSION"), "\n")),
        "list" => {
            if !options.split(args, &[])?.is_empty() {
                return Err(fail(64, "list takes no command arguments"));
            }
            inspect::list(
                manifest,
                options.all,
                &manifest.project.ui.overlay(&options.ui),
            )
        }
        "completions" if args.len() == 1 => completion::generate(manifest, &args[0]),
        "run" | "plan" | "show" | "doctor" => {
            if action == "doctor" && (args.is_empty() || args[0].starts_with('-')) {
                if !options.split(args, &[])?.is_empty() {
                    return Err(fail(64, "doctor expects a command name"));
                }
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
            let command_args = options.split(&args[1..], &command.parameters)?;
            let config = manifest
                .project
                .ui
                .overlay(&command.ui)
                .overlay(&options.ui);
            if options.complete {
                let mut words = vec!["run".into(), name.clone()];
                words.extend_from_slice(
                    command_args
                        .strip_prefix(&["--".into()])
                        .unwrap_or(&command_args),
                );
                return ui::output(
                    &completion::candidates(manifest, &aliases, &words)
                        .iter()
                        .map(|v| format!("{v}\n"))
                        .collect::<String>(),
                );
            }
            options.json_errors = config.mode() == "json";
            if action == "show" && !command_args.is_empty() && !options.help {
                return Err(fail(64, "show takes no runtime arguments"));
            }
            if options.help || action == "show" {
                return inspect::help(name, command, &config);
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
                inspect::show_plan(&plan, &config, options.ui.output.is_some())
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
fn usage() -> Result<()> {
    ui::output(
        "Praxis runs your declared commands.\n\n  praxis list [--all] [--json]\n  praxis show NAME\n  praxis plan NAME [ARGS] [--plain|--json]\n  praxis run NAME [--yes] [--non-interactive] [ARGS]\n  praxis doctor [NAME [ARGS]]\n  praxis completions fish|bash|zsh\n",
    )
}
