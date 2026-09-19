# Inspect a Praxis project

After the installed dispatcher finds `flake.nix` and evaluates its `praxis` output, built-ins describe the available commands without running them. Runner options precede the command name; everything after the name belongs to command binding or forwarding.

## Help and listing

<!-- praxis-command: runtime.help -->
```sh
praxis help
```

The project-aware help describes direct dispatch and the built-ins `list`, `help`, `show`, `plan`, `run`, `doctor`, `completions`, `complete`, and `--version`.

<!-- praxis-command: runtime.list -->
```sh
praxis list
```

<!-- praxis-output: runtime.list -->
```text
arguments	Show forwarded argument boundaries
check	Run the project checks
inspect	Evaluate the project status
list	A command whose name matches a built-in
summary	Label the evaluated status
verify	[task] Inspect the project and then run its checks
```

`list --all` includes hidden declarations, and `list --json` returns machine-readable entries.

<!-- praxis-command: runtime.help-check -->
```sh
praxis help check
```

`show` adds action, parameter, root, timeout, lock, and policy detail for inspection tools.

## Plan and diagnose

<!-- praxis-command: runtime.plan -->
```sh
praxis --json plan verify
```

<!-- praxis-output: runtime.plan -->
```json
{"command":"verify","scope":"project","steps":["inspect","check"]}
```

`plan` binds parameters, expands command references, and resolves the working directory without running actions.

<!-- praxis-command: runtime.doctor -->
```sh
praxis doctor verify
```

`doctor` checks the resolved project root and executable requirements without running the task.

## Completion scripts

<!-- praxis-command: runtime.completions -->
```sh
praxis completions fish
praxis completions bash
praxis completions zsh
```

Each invocation prints a complete script for that shell. `complete` is the lower-level query used by shell integrations.

Continue with [publishing your commands as flake outputs](outputs.md).
