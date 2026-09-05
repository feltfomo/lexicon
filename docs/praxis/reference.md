# Praxis reference

`inputs.lexicon.lib.praxis { ... }` validates the declarations with Axiom and
reports errors through Krisis. Unknown fields are errors, not ignored options.

These fields are independent of file layout. You can write the declaration in
`flake.nix`, export it from one `praxis.nix`, or import a file per command into
`commands`. The [usage guide](usage.md) shows all three. Imports are ordinary
Nix: a command file returns a string, step list, or command record, optionally
from a function whose arguments you supply. A bare path isn't a command.

## Project

| Field | Default | Meaning |
| --- | --- | --- |
| `pkgs` | required | Package set for the shared runner and runtime inputs. |
| `commands` | `{}` | Named strings, step lists, or command records. |
| `cwd` | `null` | Absolute runtime directory string. Otherwise inherit caller cwd. |
| `discoverRoot` | `null` | Find the nearest ancestor containing this relative file marker. Mutually exclusive with `cwd`. |
| `requireRoot` | `false` | Require invocation at the resolved live root with matching `flake.nix`. |
| `root` | `null` | Nix path containing a regular `flake.nix`; required only for the opt-in guard. Never a runtime cwd. |

Command names match `[a-zA-Z0-9][a-zA-Z0-9_-]*`. `praxis` is reserved for the
dispatcher. Runtime directory and script paths are strings, not Nix paths.

## Command record

| Field | Default | Meaning |
| --- | --- | --- |
| `steps` | required | Nonempty ordered list. |
| `description` | `"Run <name>"` | Help and package description. |
| `runtimeInputs` | `[]` | Derivations added to the command's child PATH. |
| `env` | `{}` | Environment names mapped to literal strings. |
| `cwd` | `null` | Absolute or clean relative runtime directory. |
| `parameters` | `[]` | Typed named or positional arguments. |
| `lock` | `null` | Command-style name of a nonblocking user-wide lock. |
## Step

A string is shorthand for `{ run = "..."; }`. Records choose exactly one form:

| Form | Value | Execution |
| --- | --- | --- |
| `run` | Nonempty string | Pinned Bash with `--noprofile --norc -euo pipefail -c`; step `args` become `$1` onward. |
| `exec` | Nonempty argv list | Direct process, no shell parsing. First item must be a nonempty executable string. |
| `script` | Clean relative path string | Live regular file contained within the step cwd. |
| `command` | Declared name | Expand a referenced command with its own argument binding. |

Every form supports `label` (defaults to source/name/executable), `args = []`,
`env = {}`, `cwd = null`, `confirm = null`, and `forwardArgs = false`.
`interactive = false` is the default; enable it on executable steps to inherit
stdin and hand over a controlling terminal. Noninteractive stdin is closed.
`interpreter` is an optional nonempty executable name or path, only for scripts.
Declare interpreter arguments in your script or use `exec` instead.

An argv item is a string or `{ param = "name"; }`. No implicit splitting,
interpolation, globbing, or evaluation occurs. At most one step per command
can have `forwardArgs = true`. References and cycles are checked before launch.

## Parameters

Each record has `name`, `description = ""`, `type = "string"`,
`positional = false`, `required = false`, and `default = null`.
Types are `string`, signed 64-bit `int`, `bool`, and nonempty `path`. A path is a
string value; it is not an existence check or an automatic cwd change.
Names match `[a-zA-Z][a-zA-Z0-9-]*`; `help`, `plain`, and `yes` are reserved.
Names must also be unique after conversion to uppercase environment names.
Required parameters cannot have defaults. Boolean positionals are not supported.
Required positionals must come before optional ones.

Named values accept `--name=value` or `--name value`. A bare boolean flag means
true; use `--name=false` for false. Use the equals form for values beginning with
reserved option tokens. Missing optional booleans become `false`; other missing
optional values become empty strings. Duplicates, unknown flags, missing values,
and wrong types fail before execution. `--` begins pass-through arguments, not
positional binding. Values are also available as `PRAXIS_ARG_<UPPER_NAME>` with
hyphens changed to underscores.

## Scope and lifecycle

A command inherits the invoking scope. Its `cwd`, `env`, and runtime input PATH
are applied, then step overrides. A referenced command starts from that step's
scope and applies its own overrides. Referenced-command inputs precede enclosing
inputs, which precede the inherited PATH; an explicit `env.PATH` overrides that
PATH. Parameter environment values override the command's `env` entries;
step environment entries apply last. A confirmation on a reference is inherited
by each executable step it expands to.

All reachable locks are acquired in sorted order before execution and held
until cleanup. They use advisory `flock` files under private `/tmp/praxis-<uid>`.
Lock files remain after exit so competing processes use the same inode. Do not
delete lock files while commands may be running. Locks do not cross machines,
users, or separate `/tmp` namespaces.
## Outputs and CLI

- `packages.<name>` and `apps.<name>` — direct executable and flake app.
- `cli` — packaged dispatcher named `praxis`.
- `package` — dispatcher plus every direct executable.
- `runner` — shared implementation; normally use a launcher, not this directly.
- `manifests.<name>` — manifest value for one reachable command set.
- `manifest` — complete normalized manifest value, with `version = 1`.
- `diagnostics.<name>` — structured reachable declaration errors without building.
- `diagnosticSummaries.<name>` — `total`, `hasErrors`, `bySeverity`, and `byCode` counts for that reachable command set, without rendering messages or forcing siblings.

Typed argument/default errors keep the existing Praxis codes and add safe `context.validation` metadata with a zero-based path, expected shape, actual outer shape, and reason. Failed argument alternatives can emit multiple diagnostics at one path; a successful alternative discards earlier failures.

`praxis list`, `praxis show NAME`, `praxis plan NAME [ARGS]`, `praxis run NAME
[ARGS]`, `praxis completions fish|bash|zsh`, and `praxis --version` form the CLI.
Direct commands and `run` accept `--help`, `--plain`, and `--yes` before `--`.
`plan` emits JSON and performs argument/root-policy validation, not execution.

## Exit statuses

Child failures preserve the child's exit code. Signals use `128 + signal`.
Praxis errors use 64 for usage, arguments, unknown commands, root guard, or
declined confirmation; 65 for invalid manifests, cycles, or script escapes; 66 for missing runtime
files/directories; 70 for internal process errors; 73 for lock storage errors;
74 for I/O errors; 75 for a busy lock; 126 for a non-executable/permission failure;
and 127 for a missing executable. Earlier side effects are never rolled back.
