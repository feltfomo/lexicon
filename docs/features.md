# Lexicon feature list

This page is the overview: every capability Lexicon offers, grouped by subsystem, with a link to the page that teaches it. It lists what you can declare, turn on, or run — not installation or ordinary setup. Use it to find out whether something exists and where to learn it. Use each subsystem's reading order when you want to learn one from the beginning, and its reference when an exact field or default matters.

## Registry

Registry is the one place a configuration says which hosts and users exist. Reading order: [Registry contents](registry/README.md). Exact fields: [reference](registry/reference.md).

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Conventional `lexicon.nix` | One visible place for shared fleet facts without filename discovery | [Getting started](registry/getting-started.md) |
| Separate source and live roots | A Nix source path and an optional absolute runtime checkout path | [Reference](registry/reference.md) |
| Flat host inventory | Hosts keyed by bare name, with `defaultSystem` supplying the system | [Reference](registry/reference.md#hostsname) |
| Declared dimension space | Closed host classifications with values, defaults, and required checks | [Reference](registry/reference.md#dimensionsname) |
| Normalized table | Canonical host and user records, aliases, homes, and lookup helpers | [Reference](registry/reference.md#result-fields) |
| Bound Ownerships roster | One roster every other subsystem can consume | [Reference](registry/reference.md#result-fields) |
| Optional Den layer | An existing Den fleet layered under the same registry, refinable and excludable | [Den integration](registry/den.md) |

## Praxis

Praxis turns Nix command declarations into an installed project CLI. Installing the package, exposing a `praxis` output from `flake.nix`, writing that declaration inline or in an imported file, and running commands from anywhere inside the project are the ordinary setup and expected behavior rather than capabilities; [getting started](praxis/getting-started.md) and [everyday commands](praxis/everyday-commands.md) cover them. Everything below is something you add on top.

Reading order: [Praxis contents](praxis/README.md). Exact fields: [reference](praxis/reference.md).

### Commands and tasks

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Literal argv commands | `command = [ ... ]`, where each string stays one argument | [Commands and tasks](praxis/commands-and-tasks.md) |
| Shell commands | `shell = ''...''`, run through Bash with `-euo pipefail` | [Commands and tasks](praxis/commands-and-tasks.md) |
| Script commands | `script`, a Nix path in your source or a path produced at runtime, with an optional `interpreter` | [Scripts and roots](praxis/scripts-and-roots.md) |
| Multi-step tasks | `tasks`, an ordered sequence of actions with labels and conditions | [Commands and tasks](praxis/commands-and-tasks.md) |
| Command references | A task step naming another command, so composition reuses one definition | [Commands and tasks](praxis/commands-and-tasks.md) |
| Conditional actions | `condition` on parameters, platforms, or environment values | [Commands and tasks](praxis/commands-and-tasks.md) |
| Per-command packages | `packages`, prepended to the command's runtime `PATH` | [Commands and tasks](praxis/commands-and-tasks.md) |
| Alternate and retired names | `aliases`, plus `hidden` and `deprecated` for commands you no longer want offered | [Reference](praxis/reference.md) |
| Grouped help | `category` and `examples`, which shape how a command is presented | [Reference](praxis/reference.md) |
| Execution controls | `env`, `cwd`, `timeout`, and `lock` for mutually exclusive commands | [Reference](praxis/reference.md) |
| Built-in `check` | `check = true`, a ready-made command that runs `nix flake check` | [Flake outputs](praxis/outputs.md) |

### Parameters and arguments

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Typed parameters | `string`, `int`, `bool`, and `path` values validated before anything runs | [Parameters](praxis/parameters.md) |
| Positional parameters | `praxis rebuild server` instead of `--host server` | [Everyday commands](praxis/everyday-commands.md) |
| Short flags and defaults | `short`, `default`, `required`, and `choices` | [Parameters](praxis/parameters.md) |
| Argv insertion | `{ param = "name"; }`, which inserts a bound value as exactly one argument | [Parameters](praxis/parameters.md) |
| Environment delivery | `PRAXIS_ARG_<NAME>` for shell and script actions | [Everyday commands](praxis/everyday-commands.md) |
| Argument forwarding | `forwardArgs`, passing remaining arguments through to one action | [Parameters](praxis/parameters.md) |
| Parameter groups | `exclusive` and `together` groups across several parameters | [Parameters](praxis/parameters.md) |
| Secret inputs | `sensitive` runtime-only parameters that stay out of the store and out of child output | [Interactions and policy](praxis/interactions.md) |
| Environment-sourced values | `env` on a parameter, so a value may come from the environment | [Interactions and policy](praxis/interactions.md) |

### Roots and scope

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| `atRoot` discovery | Commands that always run at the project root | [Everyday commands](praxis/everyday-commands.md) |
| Custom marker discovery | `discoverRoot`, for projects anchored by another file | [Scripts and roots](praxis/scripts-and-roots.md) |
| Fixed project directory | `cwd`, for a command that must run in one absolute location | [Scripts and roots](praxis/scripts-and-roots.md) |
| Source roots | `root`, which makes project files available to scripts and checks | [Scripts and roots](praxis/scripts-and-roots.md) |
| Root guarding | `requireRoot` and `scope`, which refuse to run against the wrong checkout | [Scripts and roots](praxis/scripts-and-roots.md) |

### Interaction and output

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Confirmations | `confirm` before a command that changes something, accepted by `--yes` | [Everyday commands](praxis/everyday-commands.md) |
| Prompts | `confirm`, `acknowledge`, and `select` prompt steps inside tasks | [Interactions and policy](praxis/interactions.md) |
| Prompt results | `PRAXIS_PROMPT_<NAME>` for later actions in the same task | [Interactions and policy](praxis/interactions.md) |
| Unattended policy | `--non-interactive` and the rules that make a command safe to automate | [Interactions and policy](praxis/interactions.md) |
| Output modes | `concise`, `verbose`, `quiet`, `plain`, and `json`, set per project, command, action, or invocation | [Interactions and policy](praxis/interactions.md) |
| Colour and progress | `color` and `progress` defaults | [Interactions and policy](praxis/interactions.md) |
| Notifications | Success, failure, bell, desktop, and a custom notification command | [Interactions and policy](praxis/interactions.md) |

### Inspection

Listing commands with `praxis list` and reading `praxis help <command>` are ordinary CLI behavior rather than additions. These go further:

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| `praxis inspect` and `summary` | What the declaration compiled to | [Runtime inspection](praxis/runtime.md) |
| `praxis plan` | The steps a command or task would run, before running it | [Runtime inspection](praxis/runtime.md) |
| `praxis doctor` | Diagnostics for one declaration | [Runtime inspection](praxis/runtime.md) |
| `praxis verify` | A declaration-wide validation pass | [Runtime inspection](praxis/runtime.md) |
| Shell completions | `praxis completions fish`, `bash`, or `zsh` | [Runtime inspection](praxis/runtime.md) |

### Flake outputs

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Published dispatcher package | `packages.<system>.praxis`, letting someone run your commands without installing Praxis | [Flake outputs](praxis/outputs.md) |
| Per-command packages and apps | `perCommand`, giving each command its own output, reachable on its own | [Flake outputs](praxis/outputs.md) |
| Command wrappers | `wrappers`, adding one executable per command plus wrapper-aware completions | [Flake outputs](praxis/outputs.md) |
| Commands as flake checks | `checks`, publishing a declared command as a flake check so CI runs the same declaration | [Flake outputs](praxis/outputs.md) |
| Development shell output | `devShell`, publishing the dispatcher in `devShells.<system>.default` | [Flake outputs](praxis/outputs.md) |
| Custom dispatcher name | `name`, renaming the published dispatcher and its outputs | [Flake outputs](praxis/outputs.md) |

### Optional Ownerships selection

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Claim-selected declarations | Commands and tasks that exist only for chosen users or hosts | [Ownerships selection](praxis/ownerships.md) |
| Selectable units | `units`, grouping selectable declarations with nested children | [Ownerships selection](praxis/ownerships.md) |
| Availability and trace | `availability.names`, plus the resolver trace and matrix when selection is enabled | [Ownerships selection](praxis/ownerships.md) |
| Roster-derived parameters | `lexicon.lib.praxisAdapters`, turning roster records into parameter values | [Advanced reference](praxis/advanced-reference.md) |

### Machine-readable surface

| Feature | What it gives you | Learn it |
| --- | --- | --- |
| Manifests | `manifest` and `manifests`, the compiled description of every declaration | [Advanced reference](praxis/advanced-reference.md) |
| Diagnostics | `diagnostics` and `diagnosticSummaries` keyed by command name | [Advanced reference](praxis/advanced-reference.md) |
| Dispatcher internals | `cli` and `runner` for integrations that need them | [Advanced reference](praxis/advanced-reference.md) |

## Ownerships, Furnish, and Program

These three are not expanded into this format yet. Until they are, use their reading orders and references:

- **Ownerships** selects and merges Nix values for particular users and hosts — [contents](ownerships/README.md), [reference](ownerships/reference.md).
- **Furnish** declares managed files, compiles a desired state, and reconciles it on NixOS — [contents](furnish/README.md), [reference](furnish/reference.md).
- **Program** groups one application's packages, modules, files, and themes — [contents](program/README.md), [reference](program/reference.md).

[Back to the Lexicon manual](README.md)
