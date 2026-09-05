# Interacting with Praxis

Use parameters for inputs known before a command starts. Use prompt steps for
decisions that belong at a particular point in a sequence. A prompt is not a
transaction boundary: declining one does not undo earlier steps.

## Choices and environment defaults

```nix
commands.build = {
  description = "Build a selected profile";
  category = "development";
  aliases = [ "b" ];
  examples = [ "praxis run build -p release" ];
  parameters = [ {
    name = "profile";
    short = "p";
    choices = [ "debug" "release" ];
    default = "debug";
    env = "BUILD_PROFILE";
  } ];
  steps = [ {
    exec = [ "cargo" "build" "--profile" { param = "profile"; } ];
    label = "Build the project";
  } ];
};
```

CLI values win over the named environment variable, which wins over `default`.
Every supplied value goes through the same type and choice validation. An
invalid environment value is an error, not a reason to fall back. `required`
can be satisfied by the environment; it cannot be combined with a static
`default`.

`choices` is a typed enum: use integers with `type = "int"`, booleans with
`type = "bool"`, and strings otherwise. Integers are normalized to decimal, so
`02`, `+2`, and `2` bind the same value and match the same condition. Completions
suggest choices for named and positional parameters, including short aliases
and `--name=value`, with runner options before or after the command. Fish,
Bash, and Zsh preserve spaces and shell metacharacters as literal values.
Control characters are omitted from the line-oriented completion protocol.

Short options accept `-p release`, `-p=release`, and `-prelease`. Boolean short
options accept `-f` and `-f=false`. Short-option bundles are not supported.
Use separate flags instead of `-abc`.

Parameter relationships are explicit:

```nix
parameterGroups = [
  { type = "exclusive"; parameters = [ "local" "remote" ]; }
  { type = "together"; parameters = [ "username" "endpoint" ]; }
];
```

Declare each named parameter in `parameters`. Groups count values supplied on
the CLI or through an environment source, even an empty string or explicit
`false`. Static defaults do not count as supplied. Sensitive parameters cannot
participate in groups.

## Prompt steps

```nix
steps = [
  { prompt.message = "Continue with the deployment?"; }
  {
    prompt = {
      type = "acknowledge";
      message = "This replaces the current deployment";
      acknowledgement = "REPLACE";
    };
  }
  {
    prompt = {
      type = "select";
      name = "target";
      message = "Choose a target";
      choices = [ "staging" "production" ];
      default = "staging";
    };
  }
  {
    run = ''deploy --target "$PRAXIS_PROMPT_TARGET"'';
    label = "Deploy the selected target";
  }
];
```

A selection accepts the literal choice or its displayed number. Enter accepts
an explicit default. `name` exports the response to subsequent steps as
`PRAXIS_PROMPT_<UPPER_NAME>`, replacing hyphens with underscores. Named
confirmation and acknowledgement prompts can export their successful response
too. Prompt responses are run-local environment values, not parameter defaults
and not substitutions into Nix or shell source. A later prompt with the same
name replaces the earlier response.

An incorrect selection or acknowledgement fails the command. EOF is a declined
input, not permission to proceed. Ctrl-C cancels the run. Prompt steps accept
`label`, `when`, `timeout`, and `ui`, but not executable arguments or
`interactive = true`.

| Prompt | Attended terminal | `--yes` | Noninteractive / CI |
| --- | --- | --- | --- |
| Confirmation | Ask; default is no unless explicitly true | Accept | Fail unless `--yes` |
| Typed acknowledgement | Require the exact text | Still require the exact text | Fail |
| Selection | Ask; accept a choice or number | Use an explicit default; fail without one | Use an explicit default; fail without one |

`--non-interactive`, any set `CI` variable, and JSON execution prevent prompt
reads. Redirected stdin or stderr also prevents prompt reads. `--yes` does not
supply secrets, passwords, acknowledgement text, or stdin for another program.
An executable step marked `interactive` is rejected under `--non-interactive`,
CI, or JSON execution. Without those policies it may receive piped stdin.

The `confirm = "Continue?"` field is available on executable and
reference steps. A confirmation attached to a reference is inherited by each
expanded executable step. Use an explicit prompt step before the reference if
you want to ask only once.

## Conditions

```nix
{
  run = "publish-release";
  label = "Publish release artifacts";
  when = {
    parameters.profile = "release";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    env.CI = "true";
  };
}
```

All fields must match. Platform entries are alternatives, matching the runner's
OS (`linux`) or architecture and OS (`x86_64-linux`). A condition with no fields
always matches. In `env`, a string means exact equality; `null` means absent.
An empty string is present, not absent.

Parameter conditions must match the declared type and, when present, one of
the parameter's choices. They use the preflight binding. Environment conditions are
checked when the step is reached, so a previous selection can control a later
step through `when.env.PRAXIS_PROMPT_TARGET = "production"`. Run-local prompt
responses take precedence over step/command environment overrides, which take
precedence over the inherited process environment. A child process cannot
change its parent's environment.

A condition on a reference gates its entire expansion. Inactive steps are
reported as skipped. Arguments and references are still validated before
execution, and reachable locks are still acquired. A false condition is not a
way to hide an invalid declaration.

## UI settings

`ui` is a reusable, sparse record. Merge it with ordinary Nix `//` or import it
from a file:

```nix
ui = {
  output = "concise";
  color = "auto";
  progress = true;
  notifications = {
    success = true;
    failure = true;
    desktop = true;
    bell = false;
    command = [ "${pkgs.libnotify}/bin/notify-send" ];
  };
};
```

Precedence follows the execution scope: project, command, reference step,
referenced command, executable step, then CLI. Notification fields merge
individually; overriding `bell` does not erase `desktop` or event selection.
No desktop or bell output is enabled by default. When a target is enabled,
both success and failure notifications default to enabled.

| Output | Behavior |
| --- | --- |
| `concise` | Step boundaries and a final summary on stderr |
| `verbose` | Also show the working directory, program, and argument count |
| `quiet` | Hide runner progress; child output and errors remain |
| `plain` | Concise output without terminal styling |
| `json` | Newline-delimited events on stdout; child output on stderr |

`--output MODE` selects a mode. `--concise`, `--verbose`/`-v`, `--quiet`/`-q`,
`--plain`, and `--json` are shortcuts. `--no-progress` hides human progress;
it does not remove JSON lifecycle events. A run that selects JSON anywhere in
its effective UI uses JSON throughout, so later steps cannot corrupt stdout.
The final `finished` event counts `succeeded`, `skipped`, `failed`, and `not_run`
separately; their sum is `total`. `skipped` means a condition did not match.
`not_run` means execution stopped before reaching a step, not that its condition
was false. An `error` event carries the exit code and diagnostic on failure.

Color accepts `auto`, `always`, or `never`, also through `--color`. Plain/JSON,
`NO_COLOR`, CI, and `TERM=dumb` suppress color. These settings control Praxis,
not the escape sequences a child program emits.

Notifications normally describe the overall command. A step with its own
`ui.notifications` also opts into a step notification. `--notify` accepts
`never`, `success`, `failure`, or `always` for desktop notifications. `--bell`
enables terminal bells. Event selection applies to both targets; `--notify never`
silences configured bells too. Bells require a terminal and are disabled in CI/JSON.

The notification command receives two final arguments: `Praxis` and a short
status message. It runs from the project's resolved base directory, or the effective
step directory for a step notification. It receives only display/session
variables, excluding any declared sensitive source, and has a three-second
delivery timeout plus process cleanup grace. Notification failure never changes
the command's exit status. Desktop availability is best-effort. No notification
includes runtime parameter values.

## Timeouts

Set `timeout = 60` on a command or step; values are whole seconds from 1 through
604800. A command's budget is shared across its expanded sequence, not reset
for every child. Nested budgets use the earliest deadline. A reference step's
timeout covers the whole referenced sequence.

Timeouts include prompts. Expiry sends SIGTERM to the active process group,
then SIGKILL after a two-second grace period. Remaining group members are
reaped and the terminal is restored before locks are released. Exit status is
124. Deliberately detached processes are outside the process-group boundary.

See [security](security.md) before passing credentials or running commands from
an unfamiliar project, and [adapters](adapters.md) for roster-backed choices.
