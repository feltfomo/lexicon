# Using Praxis

## Package a command set

In a flake-parts module, `pkgs` is already per-system:

```nix
{ inputs, ... }:
{
  perSystem = { pkgs, ... }:
    let
      tasks = inputs.lexicon.lib.praxis {
        inherit pkgs;
        commands = {
          fmt = "nix fmt";
          test = "nix flake check -L";
          check = {
            description = "Format and test the project";
            lock = "project-check";
            steps = [ { command = "fmt"; } { command = "test"; } ];
          };
        };
      };
    in {
      packages = tasks.packages // { praxis = tasks.package; };
      apps = tasks.apps // {
        praxis = { type = "app"; program = "${tasks.cli}/bin/praxis"; };
      };
      devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
    };
}
```

The command apps work without entering the shell. The shell adds individual
executables and the dispatcher to PATH:

```fish
nix run .#check
nix develop
praxis list
praxis show check
praxis plan check --plain
check
```

For a plain flake, put `tasks.packages` under `packages.${system}` and
`tasks.apps` under `apps.${system}`, adding the dispatcher as above. Praxis
itself does not require flake-parts.

## Split declarations across files

Keep the same output wiring and move the project declaration into `praxis.nix`:

```nix
# praxis.nix
{ pkgs }:
{
  inherit pkgs;
  commands = {
    test = "nix flake check -L";
    build = import ./commands/build.nix { inherit pkgs; };
  };
}
```

Then construct it with:

```nix
tasks = inputs.lexicon.lib.praxis (import ./praxis.nix { inherit pkgs; });
```

A per-command file returns a command, not another project:

```nix
# commands/build.nix
{ pkgs }:
{
  description = "Build the application";
  runtimeInputs = [ pkgs.cargo ];
  steps = [ { exec = [ "cargo" "build" ]; } ];
}
```

Imports are ordinary Nix imports. They can receive shared values explicitly;
Praxis does not scan directories or choose a module layout for you.

## Choose an execution form

Use `exec` when argument boundaries matter:

```nix
{ exec = [ "printf" "%s\\n" "a value with spaces" ]; }
```

Use `run` for shell syntax. It runs Bash with strict error, undefined-variable,
and pipeline handling. The `args` field supplies positional shell arguments:

```nix
{
  run = ''printf '%s\n' "$1"'';
  args = [ "a literal value" ];
  label = "Print the selected value";
}
```

A short one-line script can label itself. Multiline or long scripts receive a
command/step label rather than printing their source. Set `label` when the
operation has a useful name.

Use `script` for a file in the live checkout:

```nix
{ script = "scripts/release"; args = [ "--check" ]; }
{ script = "scripts/report.py"; interpreter = "python3"; }
```

A script without an interpreter must be executable. Script paths stay beneath
the effective working directory, including after symlink resolution. An earlier
step may generate the file; `doctor` can only inspect what exists now.

Add executables to `runtimeInputs` instead of assuming every contributor has
them on PATH. A referenced command's inputs precede its caller's inputs. An
explicit `env.PATH` overrides that constructed path.

## Parameters and references

```nix
commands = {
  greet = {
    parameters = [ { name = "person"; positional = true; required = true; } ];
    steps = [ {
      exec = [ "printf" "Hello, %s!\\n" { param = "person"; } ];
    } ];
  };
  greet-team.steps = [
    { command = "greet"; args = [ "Alice" ]; }
    { command = "greet"; args = [ "Sam" ]; }
  ];
};
```

Each reference binds its arguments independently. All ordinary bindings are
checked before the first step runs. Calls preserve order and repetitions.
A missing required argument in a later reference prevents earlier effects.

Parameters also reach children as `PRAXIS_ARG_<UPPER_NAME>`. Quote those
variables in shell scripts. Their values are not interpolated into source.
See [choices and defaults](interaction.md#choices-and-environment-defaults)
for enums, short flags, environment sources, and parameter groups.

Pass-through arguments require one declared `forwardArgs = true` step:

```nix
commands.test = {
  steps = [ { exec = [ "cargo" "test" ]; forwardArgs = true; } ];
};
```

```fish
praxis run test -- --workspace --lib
```

`--` stops runner option parsing. A parameter's value can also literally be
`--yes` or `--json`; it is consumed as the parameter value, not as a runner flag.

## Working directories and project roots

The default is the caller's directory. Relative command and step `cwd` values
compose with their enclosing scope. A process's own `cd` or exported variable
does not change the next step.

At project level choose either `cwd = "/absolute/path"` or
`discoverRoot = "flake.nix"`. Discovery finds the nearest ancestor containing
the marker. For a checkout guard, set `root = ./.; requireRoot = true;` at build
time. That verifies the caller's regular `flake.nix` once and rejects subdirectory
or store-root invocation. See the [security boundary](security.md).

## Inspect and troubleshoot

```fish
praxis list --all --verbose
praxis show build
praxis plan build --plain
praxis plan build --json
praxis doctor build
```

`list` hides commands marked `hidden` unless `--all` is used. Aliases work with
`run`, `show`, `plan`, and `doctor`; they do not create extra per-command Nix
packages. A deprecation notice warns but does not prevent execution.

`plan` defaults to JSON. It shows bound parameters, expanded reference chains,
locks, prompts, conditions, working directories, and timeout scopes. It neither
prompts nor runs anything. `show` does not require runtime arguments. `doctor`
does, because executable paths and directories can depend on those arguments.
With no name, doctor checks all visible commands and reports those needing
arguments as failures; inspect individual commands with explicit values instead.

Use `--plain` to remove Praxis styling, `--quiet` to hide its progress, or
`--json` for newline-delimited execution events. Child output is live; JSON
moves it to stderr. [Interaction settings](interaction.md) cover scoped UI,
notifications, prompts, CI policy, and timeouts.

## Install completions

With `praxis` on PATH:

```fish
praxis completions fish > ~/.config/fish/completions/praxis.fish
```

For Bash, source the output of `praxis completions bash` from your shell setup.
For Zsh, initialize `compinit` and source `praxis completions zsh`. The generated
functions ask the installed dispatcher or command launcher for candidates, so
choices follow the installed manifest rather than a stale static word list.
