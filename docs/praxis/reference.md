# Praxis public reference

<!-- praxis-constructors: praxis praxisAdapters -->

The public constructor is `lexicon.lib.praxis`. `lexicon.lib.praxisAdapters` is a separate helper constructor for optional roster-derived parameter records. There is no public `praxisV1` constructor.

Praxis declaration records are closed. Unknown fields produce Praxis diagnostics, often with a nearby field suggestion, instead of being ignored.

Closed means an unknown name is rejected. It does not mean every valid field matters in every context. `checks`, `perCommand`, `wrappers`, and `devShell` are read only when a declaration is compiled through `lexicon.lib.praxis`; the installed command reads your `praxis` output for its command manifest and ignores those four without a diagnostic. `check` is applied to the command registry itself, so it is live on both paths. [Publishing your commands as flake outputs](outputs.md) covers the distinction.

## Generic installed interface

Place `packages.<system>.praxis` in a declarative package list — `environment.systemPackages` on NixOS or `home.packages` under Home Manager — and switch that configuration normally; see [getting started](getting-started.md) for the complete flake. The package and runtime are marked Linux-only. Lexicon declares `x86_64-linux` and `aarch64-linux` flake systems; the complete installed-consumer path is tested on `x86_64-linux`.

A project is one regular `flake.nix` that exposes a `praxis` output. The declaration has this exact function shape:

```nix
{ pkgs, root, inputs }: {
  # commands and optional tasks
}
```

`pkgs` is the selected project's `nixpkgs.legacyPackages` for the current system. `root` is the source root exported by that flake evaluation. `inputs` is the selected flake's input set. `flake.nix` must declare `inputs.nixpkgs`; a missing input or current-system package set is an evaluation failure.

The declaration may be written inline in `flake.nix` or kept in another file and imported by it, including a neighboring `praxis.nix`. Both layouts produce the same commands and the same evaluated description. The flake output is the entire contract: no filename is discovered independently, and the imported file may have any name or location.

The installed `praxis` command starts at the current directory and chooses the nearest ancestor containing `flake.nix`. Invocation from nested directories uses that nearest project. A nearer flake that exposes no `praxis` output is an error naming that project; Praxis does not continue to an unrelated parent. Outside a project, commands that need a declaration fail with exit 66. `--help`, bare `help`, and `--version` work before project discovery.

The loader builds the evaluated command description with `--no-write-lock-file` before handing control to the installed runner. Its Nix closure realizes packages referenced by command paths and reports malformed imports, invalid closed declarations, missing `nixpkgs`, and build failures as project preparation errors rather than child-process `ENOENT` failures. The loader itself does not create or update `flake.lock`. A declared command, including `nix eval`, `nix build`, or `nix flake check`, retains that program's normal lock behavior.

The `praxis` output is reevaluated on every invocation, so declaration edits do not require reinstalling the generic package. The generic command's identity remains `praxis`; a declaration-level `name` is used only when the same declaration is passed directly to `lexicon.lib.praxis` for configured output generation.

Configured packages, apps, wrappers, checks, development shells, custom names, and Ownerships selection are optional projections built with `lexicon.lib.praxis`. They share this declaration vocabulary and produce their own artifacts.

## Project fields

<!-- praxis-project-fields: pkgs name commands tasks check atRoot wrappers perCommand devShell root cwd discoverRoot requireRoot ui checks ownership units -->

| Field | Accepted value | Default and effect |
| --- | --- | --- |
| `pkgs` | Package set | Required. Supplies the runtime package builder and packages referenced by declarations. |
| `name` | Command-style string | `"praxis"`. Names the dispatcher and main package/app. |
| `commands` | Attribute set | `{ }`. Maps names to command declarations. |
| `tasks` | Attribute set | `{ }`. Maps names to task declarations. |
| `check` | Boolean | `false`. When true, synthesizes a command named `check` that runs `nix flake check`. |
| `atRoot` | Boolean | `false`. When true, runtime discovery uses a regular `flake.nix` marker. |
| `wrappers` | Boolean | `false`. When true, the main package also installs command wrappers and wrapper-aware completions. |
| `perCommand` | Boolean | `false`. When true, per-command packages and apps join the main output. |
| `devShell` | Boolean | `false`. When true, the returned `flake` attribute includes a default development shell containing the main package. |
| `root` | Nix path or `null` | `null`. Build-time source; a non-null path must contain a regular `flake.nix`. |
| `cwd` | Absolute runtime string or `null` | `null`. Selects a fixed project runtime directory. |
| `discoverRoot` | Clean relative marker or `null` | `null`. Walks upward from the caller to find the marker. |
| `requireRoot` | Boolean | `false`. Requires `root` and guards the matching live project root and regular `flake.nix`. |
| `ui` | UI record | `{ }`. Project-level output, color, progress, and notification defaults. |
| `checks` | Distinct command-name list | `[ ]`. Creates selected flake check derivations. |
| `ownership` | Ownership configuration or `null` | `null`. Enables optional selection. |
| `units` | Unit list | `[ ]`. Adds nested selectable declarations; requires `ownership`. |

`atRoot` cannot be combined with project `cwd` or `discoverRoot`. Project `cwd` and `discoverRoot` are also mutually exclusive. `check = true` conflicts with an authored command or task named `check`.

## Command and task declarations

A command may be a literal argv list, a Nix script path, or a record. A command record defines exactly one of `command`, `shell`, or `script`; a top-level command cannot be a prompt. A task may be a non-empty list of actions or a record with a non-empty `steps` list.

<!-- praxis-metadata-fields: description category aliases examples hidden deprecated scope env cwd lock timeout ui parameters parameterGroups packages confirm -->

| Shared field | Accepted value and default |
| --- | --- |
| `description` | String, default `""`. |
| `category` | Non-empty string or `null`, default `null`. |
| `aliases` | Distinct command-style names, default `[ ]`; aliases cannot shadow declarations or the dispatcher. |
| `examples` | String list, default `[ ]`. |
| `hidden` | Boolean, default `false`; hidden declarations stay out of ordinary `list`. |
| `deprecated` | Non-empty notice or `null`, default `null`. |
| `scope` | `"project"` or `"global"`, default `"project"`. |
| `env` | Attribute set of valid environment names to strings, default `{ }`. |
| `cwd` | Absolute or clean relative runtime directory, default `null`. |
| `lock` | Command-style lock name or `null`, default `null`. |
| `timeout` | Positive integer seconds up to 604800, or `null`; default `null`. |
| `ui` | UI overlay, default `{ }`. |
| `parameters` | Parameter list, default `[ ]`. |
| `parameterGroups` | Group list, default `[ ]`. |
| `packages` | Package derivation list, default `[ ]`; prepended to runtime `PATH`. |
| `confirm` | Boolean, non-empty message, or `null`. On a task it creates one leading confirmation; on a command it guards the command action. |

Command and task names match `[a-zA-Z0-9][a-zA-Z0-9_-]*` and cannot equal the dispatcher name. A command and task cannot share one name.

## Public action fields

<!-- praxis-action-fields: command shell script prompt interpreter args forwardArgs interactive confirm label condition cwd env timeout ui localFlake -->

| Field | Meaning |
| --- | --- |
| `command` | A list is literal argv. A string in a task action is a command reference. Top-level commands require the list form. |
| `shell` | Non-empty Bash source. Praxis invokes Bash with `-euo pipefail`. |
| `script` | A Nix path inside project `root`, or a clean relative runtime string. |
| `prompt` | Prompt record; accepted only as a task action. |
| `interpreter` | Non-empty executable name or path; valid only with `script`. |
| `args` | List of literal strings or `{ param = "name"; }` references. |
| `forwardArgs` | Boolean. Defaults true for a one-action non-prompt command and false for actions in a longer sequence. |
| `interactive` | Boolean, default `false`; not valid on command references or prompts. |
| `confirm` | Boolean, message, or `null`; adds a confirmation to this action. |
| `label` | Non-empty display label; otherwise derived from the action. |
| `condition` | Public condition record controlling whether the action runs. |
| `cwd` | Absolute or clean relative directory for this action. |
| `env` | Environment-string overrides for this action. |
| `timeout` | Positive seconds up to one week, or `null`. |
| `ui` | Action-level UI overlay. |
| `localFlake` | Boolean. With literal argv, prefixes each literal value in `args` with `.#`; values beginning with `-` or already containing `#` are rejected. |

Each action defines exactly one execution form. Prompt actions cannot also take `args`, `forwardArgs`, `interactive`, or `confirm`. `interpreter` is valid only with `script`. At most one expanded action may receive remaining arguments.

A string directly in a task's `steps` list is a command reference. A list directly in `steps` is literal argv. References preserve order, include transitively referenced commands, and reject unknown names and cycles.

## Parameters

<!-- praxis-parameter-types: string int bool path -->

<!-- praxis-parameter-fields: name description type positional required env short sensitive choices default -->

| Field | Accepted value | Default |
| --- | --- | --- |
| `name` | Starts with a letter; then letters, digits, or `-` | Required |
| `description` | String | `""` |
| `type` | `"string"`, `"int"`, `"bool"`, or `"path"` | `"string"` |
| `positional` | Boolean | `false` |
| `required` | Boolean | `false` |
| `env` | Valid environment name or `null` | `null` |
| `short` | One letter or `null` | `null` |
| `sensitive` | Boolean | `false` |
| `choices` | Distinct values of the parameter's type | `[ ]` |
| `default` | Value of the parameter's type or `null` | `null` |

`{ param = "name"; }` may appear in literal argv or `args`; the name is case-sensitive and must be declared on that command. Parameters also become `PRAXIS_ARG_<NAME>` environment values for shell and script actions.

Required positional parameters precede optional positional parameters, ignoring named parameters between them. Boolean parameters are named flags, positional parameters cannot have short flags, required parameters cannot have defaults, defaults must belong to non-empty choices, short flags must be unique, and parameter names must remain unique when converted to environment variable names.

A parameter group is `{ type = "exclusive" | "together"; parameters = [ ... ]; }`. It names at least two distinct, declared, non-sensitive parameters. An exclusive group permits at most one supplied member; a together group accepts either none or every member.

Sensitive parameters are named runtime-only strings. They cannot be positional, typed otherwise, statically defaulted, constrained by choices, placed in argv, groups, or conditions, or share protected environment sources with ordinary values. Their child output is suppressed.

## Prompts and conditions

A prompt record accepts:

| Field | Shape and default |
| --- | --- |
| `type` | `"confirm"`, `"acknowledge"`, or `"select"`; default `"confirm"`. |
| `message` | Required non-empty string. |
| `name` | Parameter-style name or `null`; required for `select`. |
| `acknowledgement` | Non-empty string or `null`; required only for `acknowledge`. |
| `choices` | Distinct non-empty strings; required and non-empty only for `select`. |
| `default` | `null`; a Boolean for `confirm`, or one declared choice for `select`. |

A named selection becomes `PRAXIS_PROMPT_<NAME>` for later actions. Confirm prompts may be accepted by `--yes`; select prompts can run unattended only with a default; acknowledgements require exact terminal input.

A `condition` record accepts `parameters`, `platforms`, and `env`. `parameters` maps declared non-sensitive names to type-correct values; a value constrained by choices must use a declared choice. `platforms` is a list of non-empty operating-system or architecture-system strings. `env` maps valid environment names to a required string or `null` for absence.

## Interactions, UI, and sensitive inputs

A UI record accepts `output`, `color`, `progress`, and `notifications`.

- `output` is `concise`, `verbose`, `quiet`, `plain`, or `json`.
- `color` is `auto`, `always`, or `never`.
- `progress` is Boolean.
- `notifications` may set Boolean `success`, `failure`, `bell`, and `desktop`, plus `command` as non-empty literal argv.

Project UI is overlaid by command UI, action UI, then invocation flags. Notification commands receive a title and result message and do not inherit protected sensitive environment names.

## Roots, scope, and scripts

With no root policy, the runtime uses the caller's directory. `atRoot` discovers a regular `flake.nix`; `discoverRoot` discovers another regular marker; project `cwd` chooses an absolute directory. Relative command and action `cwd` values join the enclosing resolved directory.

`root` is build-time source and never becomes a runtime `cd` by itself. A Nix path used as `script` must be inside `root`; it remains anchored to the matching live project root if the command changes `cwd`. A relative script string resolves against the live runtime directory when the action executes, so an earlier step may create it. Script resolution canonicalizes the live file, requires a regular file, and rejects escapes through traversal or symlinks.

A project-scoped command can be entered only from the resolved project root or a descendant. A global command may enter a configured absolute root from elsewhere. `requireRoot` additionally requires the matching root itself, refuses a store checkout, requires a regular non-symlink `flake.nix`, and compares its contents with the build-time source.

## Flake check eligibility

`check = true` adds a normal command; `checks = [ ... ]` creates derivations. Every selected check name must exist.

A selected flake check is rejected if its transitive declaration contains:

- a sensitive parameter, an environment-sourced parameter, or a required parameter without a default;
- a prompt, confirmation, or interactive action;
- a fixed project `cwd`, or an absolute command/action `cwd`;
- root discovery, `requireRoot`, or a script without `root` source.

An eligible check runs non-interactively in a fresh build directory. When `root` is present, the source is copied there and made writable before dispatch.

## Optional ownership configuration

`ownership` accepts `roster` and `context` as required fields, `scope` as `"system"` or `"user"` with default `"system"`, and an optional Ownerships-compatible `engine` whose default is the bundled engine.

Direct commands and tasks may carry Ownerships claim fields. Units may carry those claims plus `label`, `source`, `commands`, `tasks`, and nested `children`. Claims select units; the selected command and task fields then follow the ordinary declaration rules. `units` without `ownership` fail.

`availability.names` is always present. Without selection, it contains every direct declaration while `trace` and `matrix` are `null`. With selection, names, trace, and matrix come from the strict Ownerships resolver.

## Returned Praxis surface

<!-- praxis-result-fields: package packages apps checks devShell cli runner manifest manifests diagnostics diagnosticSummaries commandPackages commandApps availability flake -->

Normal-use values:

- `package`: main dispatcher package, or dispatcher plus wrappers when `wrappers = true`.
- `packages`: named main package plus per-command packages when enabled.
- `apps`: named main app plus per-command apps when enabled.
- `checks`: selected flake check derivations.
- `devShell`: development shell value; the returned `flake` attribute publishes it only when enabled.
- `flake`: system-indexed `packages`, `apps`, `checks`, and optional default development shell.

Inspection and advanced values:

- `cli`: dispatcher-only package.
- `runner`: underlying runtime package.
- `manifest`: machine-readable description of all available declarations and transitive references.
- `manifests`: machine-readable command views keyed by command name.
- `diagnostics` and `diagnosticSummaries`: validation results keyed by command name.
- `commandPackages` and `commandApps`: per-command artifacts whether or not they are published by the returned `flake` attribute.
- `availability`: names and optional Ownerships trace/matrix.

The [advanced reference](advanced-reference.md) explains how to inspect these values without treating machine-readable results as authoring input.
