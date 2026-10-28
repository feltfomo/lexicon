# Praxis API

`inputs.lexicon.lib.praxis spec` compiles a command project. Public declarations
use `command`, `shell`, `packages` and `condition`. Internal execution fields
`exec`, `run`, `runtimeInputs` and `when` are not accepted public action names.

## Project

| Field | Type | Default / meaning |
| --- | --- | --- |
| `pkgs` | Nixpkgs package set | Required |
| `name` | Command-style name | `"praxis"`; dispatcher executable and output name |
| `commands` | Attribute set keyed by command name | `{}` |
| `tasks` | Attribute set keyed by task name | `{}` |
| `scope` | `"project"` or `"global"` | `"project"`; inherited by commands and tasks unless overridden |
| `check` | Boolean | false; adds `check` running `nix flake check` |
| `atRoot` | Boolean | false; discovers enclosing `flake.nix` |
| `root` | Nix path containing regular `flake.nix`, or null | null; source for scripts, source guards and checks |
| `cwd` | Absolute runtime directory string or null | null |
| `discoverRoot` | Normalized relative marker filename or null | null |
| `requireRoot` | Boolean | false; requires `root` for the flake source guard |
| `wrappers` | Boolean | false; installs individual command wrappers in the main package |
| `perCommand` | Boolean | false; publishes individual command packages/apps alongside dispatcher |
| `devShell` | Boolean | false; includes a default dev shell in `.flake` outputs |
| `checks` | List of distinct command names | `[]`; commands to execute as Nix flake checks |
| `ui` | UI attribute set | `{}` |
| `ownership` | Ownership configuration or null | null |
| `units` | List of ownership command groups | `[]`; requires `ownership` |

`atRoot` cannot coexist with `cwd` or `discoverRoot`. `cwd` cannot coexist with
`discoverRoot`. `check = true` conflicts with a declared command/task `check`.
Unknown project fields are rejected.
Project scope requires invocation from the resolved project directory or below;
global scope allows invocation elsewhere. With `requireRoot`, the live
`flake.nix` must match the compiled source and project scope requires invocation
at the root itself.

## Commands and tasks

Command declarations are a literal non-empty argv list, a Nix script path, or
an attribute set containing exactly one of `command`, `shell`, `script`.
`command` must be an argv list. Task declarations are a non-empty step list or
an attribute set with required non-empty `steps`. A string task step names
another command/task. A list step is argv; a Nix path step is a script.

Command/task names match `[a-zA-Z0-9][a-zA-Z0-9_-]*`, must be unique across both
collections and cannot equal the dispatcher name. References cannot form cycles.

Commands can be grouped with nested attributes:

```nix
commands.update.input = {
  positional = [ "input" ];
  parameters.input.choices = builtins.attrNames inputs;
  command = [ "nix" "flake" "update" { param = "input"; } ];
  forwardArgs = false;
};
```

This declares `praxis update input <input>`. A non-empty command attribute set
without declaration fields is a namespace; its child names must not be action
or metadata field names. Help and completion list the available subcommands.
Task references use the attribute path, such as `"update.input"`; a namespace
itself is not an executable task step.

Selection keeps unrelated namespace children lazy. Individual manifests,
packages, apps and availability entries are keyed by top-level names. A namespace
wrapper accepts its subcommand as the first argument. Manifest command keys use
dotted paths, such as `"update.input"`; human-readable help lists command words.

| Shared field | Type | Default / meaning |
| --- | --- | --- |
| `description` | String | `""` |
| `category` | Non-empty string or null | null |
| `aliases` | Distinct command-style name list | `[]`; cannot include its own name or shadow dispatcher |
| `examples` | String list | `[]` |
| `hidden` | Boolean | false; omitted from ordinary listing |
| `deprecated` | Non-empty notice string or null | null |
| `scope` | `"project"` or `"global"` | Inherits project scope |
| `packages` | List of package derivations | `[]`; runtime PATH inputs |
| `env` | Attribute set of strings keyed by POSIX environment names | `{}` |
| `cwd` | Absolute or normalized relative directory string, or null | null |
| `lock` | Command-style name or null | null; runtime lock |
| `timeout` | Integer seconds, 1 through 604800, or null | null |
| `ui` | UI attribute set | `{}` |
| `parameters` | Attribute set keyed by parameter name | `{}` |
| `positional` | List of declared parameter names | `[]`; determines positional argument order |
| `parameterGroups` | Group declaration list | `[]` |
| `confirm` | Boolean, non-empty prompt string or null | null; true generates a prompt; task confirmation precedes its steps |

## Actions / steps

Each action defines exactly one execution form:

| Form | Value | Meaning |
| --- | --- | --- |
| `command` | Non-empty argv list | Execute argv without shell parsing |
| `command` | Command-style name string | Reference a declared command/task; valid in task steps |
| `shell` | Non-empty shell source string | Execute shell source; argument placement belongs in the authored source |
| `script` | Normalized relative path string or Nix path | Execute source script |
| `prompt` | Prompt record | Interactive task step |

Optional action fields are `label`, `args ? []`, `cwd ? null`, `env ? {}`,
`timeout ? null`, `ui ? {}`, `condition ? {}`, `interactive ? false`,
`confirm ? null`, `forwardArgs`, `interpreter`, `localFlake`.
`args` and argv entries accept strings or exactly `{ param = "parameter-name"; }`.
Executable argv must start with a non-empty string. `interpreter` is only valid
for a script and must name one executable. Public command declarations also
accept these action fields except `prompt`.

`forwardArgs` defaults true for a single action and false for a multi-step task;
prompt actions default false. At most one step may forward arguments.
`interactive` requires terminal execution; put it on the executable step rather
than a command reference. Script Nix paths require `root` and must lie beneath
it; relative strings use runtime script resolution.
`localFlake = true` is only valid for argv actions whose `args` are literal
output names without leading `-` or `#`; it converts them to `.#<name>`.

## Parameters

Declare each parameter under its name and list positional arguments in their
runtime order:

```nix
positional = [ "host" ];
parameters = {
  host.choices = [ "khion" "lumi" ];
  mode = {
    short = "m";
    default = "debug";
    choices = [ "debug" "release" ];
  };
};
```

Positional arguments without a default are required unless explicitly overridden
with `required = false`. Named arguments remain optional unless `required = true`.
Positionals must name declared parameters and cannot repeat. Named parameters
follow positionals in sorted name order. Parameter lists and per-parameter `name`
or `positional` fields are rejected; the compiler owns the ordered runtime list.

Parameter attribute names match `[a-zA-Z][a-zA-Z0-9-]*`.

| Field | Type | Default / meaning |
| --- | --- | --- |
| `description` | String | `""` |
| `type` | `"string"`, `"int"`, `"bool"`, `"path"` | `"string"`; path means non-empty runtime string |
| `required` | Boolean | Positional without default: true; otherwise false |
| `env` | POSIX environment name or null | null; fallback source |
| `short` | One ASCII letter or null | null |
| `sensitive` | Boolean | false |
| `choices` | Distinct list of values matching type | `[]` |
| `default` | Value matching type or null | null |

Explicit argv takes precedence over environment fallback, then static default.
Values are exported as `PRAXIS_ARG_<UPPERCASE_NAME>`, replacing `-` with `_`.
Parameter names must have distinct normalized environment names. Short flags
must be unique. Required positional arguments precede optional ones.
Absent optional parameters resolve to false for booleans and an empty string
for other types when no fallback or default exists.
Positional parameters cannot use short flags or boolean type. Required
parameters cannot have defaults; a non-null default must belong to choices when
choices are supplied.

Sensitive parameters must be named strings; they reject even explicitly empty
`choices` or null `default` fields. Runtime values come from environment or
terminal input, never argv. Sensitive parameters cannot appear in argv
references, conditions or parameter groups, and their environment sources
cannot be overridden by command/step `env`.

Parameter groups require `type = "exclusive"` or `"together"` and a list
`parameters` containing at least two distinct declared, non-sensitive names.
`exclusive` permits at most one supplied parameter; `together` permits none or
all. Environment fallbacks count as supplied; static defaults do not.

## Conditions, prompts and UI

`condition` accepts `parameters ? {}` (name to typed literal comparison),
`platforms ? []` (platform strings), `env ? {}` (environment name to string
or null). Parameter comparisons must use declared parameters and valid choices.
All condition fields must match; platform alternatives match the runtime OS
name or `architecture-OS` name. Null environment comparisons require absence.

A prompt requires non-empty `message`. Optional fields:
`type ? "confirm"`, `name ? null`, `acknowledgement ? null`, `choices ? []`,
`default ? null`. Types are `"confirm"`, `"acknowledge"`, `"select"`.
Select requires a name and non-empty unique choices, with any default among
those choices. Acknowledge requires non-empty acknowledgement text and has no
default. Confirm defaults may be boolean. Choices and acknowledgement text are
restricted to their respective prompt types. Prompt steps reject `args`,
`forwardArgs = true`, `interactive = true`, and non-null `confirm`.
Named prompt responses become `PRAXIS_PROMPT_<UPPERCASE_NAME>` for later steps,
replacing `-` with `_`. `--yes` accepts confirmations; selection needs a
default when unattended, and typed acknowledgement still requires a terminal.

`ui` accepts `output` (`concise`, `verbose`, `quiet`, `plain`, `json`), `color`
(`auto`, `always`, `never`), boolean `progress`, and `notifications`.
Notifications accept boolean `success`, `failure`, `bell`, `desktop`, plus
`command` (non-empty literal notification argv). Unspecified UI fields inherit;
project, command and step settings are overlaid by runtime options.

## Ownership and outputs

`ownership` requires `roster` and `context`; optional `scope` defaults to
`"system"` (`"user"` also accepted), and `engine` defaults to Lexicon ownerships.
Command/task records may then carry ownership claims. Group units accept claims,
`label`, `source`, `commands ? {}`, `tasks ? {}`, `children ? []`.
Selection uses a strict ownership resolver before command compilation.

| Result field | Meaning |
| --- | --- |
| `package` | Dispatcher CLI, plus wrappers when requested |
| `packages`, `apps` | Dispatcher outputs, plus individual outputs when `perCommand` is true |
| `checks` | Requested command check derivations |
| `devShell` | Shell containing the selected package |
| `cli`, `runner` | Generated CLI and shared manifest runner packages |
| `manifest`, `manifests` | Dispatcher manifest attribute set and command-name to manifest attribute sets |
| `diagnostics`, `diagnosticSummaries` | Command-name to diagnostic lists and summaries |
| `commandPackages`, `commandApps` | Individual outputs regardless of `perCommand` |
| `availability` | `{ names, trace, matrix }`; trace/matrix null without ownership |
| `flake` | System-keyed packages/apps/checks and optional default dev shell |

Flake checks reject prompts, terminal requirements, sensitive/environment
parameter sources and required parameters without defaults. They also reject
fixed runtime directories. Script/root-dependent checks require `root`.

`inputs.lexicon.lib.praxisAdapters {}` exposes `fromRoster roster` returning
`{ host.choices = sortedHosts; user.choices = sortedUsers; }`. Assign these
descriptors to `parameters.host` or `parameters.user`.
`fromDen denAdapter` applies `fromRoster` to `denAdapter.roster`.

## Generated CLI

| Invocation | Meaning |
| --- | --- |
| `<name> [runner-options] COMMAND [args...]` | Run command or alias |
| `<name> run COMMAND [args...]` | Explicit run; required for names colliding with built-ins |
| `<name> list [--all]` | List commands, including hidden ones with `--all` |
| `<name> help [COMMAND]`, `<name> show COMMAND` | Usage or command description |
| `<name> plan COMMAND [args...]` | Bind arguments and show plan |
| `<name> doctor [COMMAND [args...]]` | Check runtime requirements |
| `<name> completions fish\|bash\|zsh [--wrappers]` | Emit shell completion definitions |
| `<name> --version` | Print dispatcher version |

Runner options precede the command: `--yes`/`-y`, `--non-interactive`,
`--help`/`-h`, `--concise`, `--verbose`/`-v`, `--quiet`/`-q`, `--plain`,
`--json`, `--output MODE`, `--color MODE`, `--no-progress`, `--notify WHEN`,
`--bell`. Notification modes are `never`, `success`, `failure`, `always`.
Everything after the command belongs to its argument grammar.
Named parameters accept `--name value`, `--name=value`, and declared short flags.
Boolean flags without a value mean true. Typed parsing stops at `--` or the
first forwarded argument. Commands without declared parameters preserve literal
arguments, including `--`.

Compilation uses the shared native Krisis/nix-effects dependency owner. Axiom
still interprets field specifications and validates ownership name collisions.
Command normalization is shared at each demanded graph node. Diagnostics and
summaries select reachability without building packages or reading runtime input
paths. Native type blame is mapped to the established Praxis diagnostic records.
The manifest remains version 2; execution belongs to the existing Rust runner.
