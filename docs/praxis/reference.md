# Praxis reference

`inputs.lexicon.lib.praxis { ... }` returns compiled outputs. Unknown fields are
errors. Names and references are validated before packaging; selected command
outputs do not force unrelated command bodies.

## Project fields

| Field | Default | Meaning |
| --- | --- | --- |
| `pkgs` | required | Nixpkgs package set for the runner and launchers |
| `commands` | `{ }` | Attribute set of command declarations |
| `root` | `null` | Build-time Nix path used by the optional root guard |
| `cwd` | `null` | Absolute runtime working directory |
| `discoverRoot` | `null` | Relative marker used for nearest-ancestor discovery |
| `requireRoot` | `false` | Require the caller to match the declared root's flake |
| `ui` | `{ }` | Project-wide UI defaults |

`cwd` and `discoverRoot` are mutually exclusive. `requireRoot` needs `root`
containing a regular `flake.nix`. It is a check, not an implicit directory change.

## Commands

A string is shorthand for one `run` step. A list is shorthand for `{ steps =
list; }`. A record accepts:

| Field | Default | Meaning |
| --- | --- | --- |
| `steps` | required | Nonempty ordered list |
| `description` | `"Run <name>"` | Help and list text |
| `runtimeInputs` | `[ ]` | Executable packages prepended to PATH |
| `env` | `{ }` | Literal string environment overrides |
| `cwd` | `null` | Directory relative to the enclosing scope, or absolute |
| `lock` | `null` | Same-user advisory lock name |
| `parameters` | `[ ]` | Parameter declarations |
| `parameterGroups` | `[ ]` | Exclusive or required-together groups |
| `category` | `null` | Display category |
| `aliases` | `[ ]` | Dispatcher aliases; unique across the manifest |
| `examples` | `[ ]` | Usage examples shown in help |
| `hidden` | `false` | Omit from default list and completion |
| `deprecated` | `null` | Warning text; execution is still allowed |
| `timeout` | `null` | Whole-command seconds, including nested steps and prompts |
| `ui` | `{ }` | Command UI overrides |

Command names match `[a-zA-Z0-9][a-zA-Z0-9_-]*`; `praxis` is reserved. Aliases
cannot shadow command names. They do not create wrapper packages.

## Steps

A string is a `run` step. A record must have exactly one execution form:

| Form | Value |
| --- | --- |
| `run` | Nonempty Bash source |
| `exec` | Nonempty argv list; first entry is a literal executable |
| `script` | Clean relative live-script path |
| `command` | Reference to a declared command |
| `prompt` | Prompt record described below |

Shared fields are `label`, `cwd`, `env`, `when`, `timeout`, and `ui`. Executable
and reference steps also accept `args`, `confirm`, and `forwardArgs`.
`interactive = true` gives an executable step stdin and foreground terminal
ownership; it is not allowed on references or prompt steps. Only `script`
accepts `interpreter`, which is a single executable name/path, not a shell line.

`args` and `exec` entries are strings or `{ param = "declared-name"; }`. An
empty string is a valid literal argument. At most one step in each command can
receive pass-through arguments. Reference arguments bind the referenced
command's parameters; they are not automatically inherited by name.

A missing label uses the executable, script, reference, or prompt message.
Long and multiline `run` source uses `<command> (step <number>)` instead.

### Prompt record

- `type`: `confirm` (default), `acknowledge`, or `select`.
- `message`: required nonempty text.
- `name`: optional response name; required for selection.
- `acknowledgement`: required exact text for `acknowledge`; otherwise absent.
- `choices`: nonempty, unique strings for `select`; otherwise absent.
- `default`: a boolean for confirmation, one declared choice for selection,
  or absent. Acknowledgement has no default.

Prompt steps cannot also declare `args`, `forwardArgs`, `interactive`, or
`confirm`. See the [interaction policy](interaction.md#prompt-steps).

### Conditions and timeouts

`when.parameters` maps parameter names to string/int/bool equality values.
`when.platforms` is a list of OS or architecture-OS names. `when.env` maps
variable names to exact strings or `null` for absence. Fields combine with AND;
platform alternatives combine with OR. Empty conditions match.

Timeouts are positive integer seconds, at most 604800. A reference timeout
covers the expansion. Command and nested deadlines are shared budgets, not
per-child resets. Earliest expiry wins; exit status is 124.

## Parameters

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | required | `[a-zA-Z][a-zA-Z0-9-]*` name |
| `description` | `""` | Help text |
| `type` | `"string"` | `string`, `int`, `bool`, or `path` |
| `required` | `false` | Require a CLI/environment value |
| `positional` | `false` | Bind by position instead of a named flag |
| `default` | `null` | Static typed default, normalized into the manifest |
| `choices` | `[ ]` | Typed enum values; empty means unrestricted |
| `env` | `null` | Runtime environment source |
| `short` | `null` | One letter, excluding `h`, `y`, `q`, and `v` |
| `sensitive` | `false` | Runtime-only named string input |

Names must have unique `PRAXIS_ARG_<UPPER_NAME>` forms. Runner option names are
reserved. Required positional arguments precede optional ones. Named flags may
be interleaved with positionals. Boolean parameters cannot be positional.

`int` uses signed 64-bit decimal values. `path` means a nonempty runtime string,
not a Nix path or an existence check. Choices and defaults use the declared
type. CLI values take precedence over environment values, then static defaults.

A group is `{ type = "exclusive"; parameters = [ "a" "b" ]; }` or
`{ type = "together"; parameters = [ "a" "b" ]; }`. It needs at least two
unique, declared, non-sensitive names. Groups count explicit CLI/environment
presence, not static defaults.

Sensitive parameters have no static values, choices, positional form, or argv
substitution. See [runtime credentials](security.md#runtime-credentials).

## UI record

`ui` accepts `output`, `color`, `progress`, and `notifications`. All are sparse
overrides. Notification fields are `success`, `failure`, `bell`, `desktop`, and
`command` (a nonempty literal argv list). [Interaction settings](interaction.md#ui-settings)
define precedence, CLI overrides, output channels, and notification behavior.

## Outputs

| Attribute | Contents |
| --- | --- |
| `packages.<name>` | Individual command launcher |
| `apps.<name>` | Nix app for that launcher |
| `manifests.<name>` | Selected command plus reachable declarations |
| `manifest` | All-command manifest |
| `runner` | Shared runtime package |
| `cli` | Dispatcher package |
| `package` | Dispatcher and individual launchers |
| `diagnostics.<name>` | Structured selected-command diagnostics |
| `diagnosticSummaries.<name>` | Total, severity/code counts, and `hasErrors` |

Manifest version is 1. `plan` defaults to JSON with bound parameters, expanded
steps, reference chains, conditions, prompts, deadlines, and sensitive source
descriptors. Consumers should tolerate additional fields. Execution `--json`
is a separate newline-delimited event stream, not one plan document.
