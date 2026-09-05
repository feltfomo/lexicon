# Using Praxis

Praxis supports three declaration layouts: inside `flake.nix`, one separate
`praxis.nix` containing all commands, or one Nix file per command. The same
project, command, step, and parameter options work in all three. File layout
isn't part of the runtime manifest.

The examples use a project's formatter and `scripts/test.sh`. Supply those or
replace their commands with your existing tools. Add a `lexicon` flake input as
shown in the [quickstart](../praxis.md); Lexicon supplies Axiom and Krisis.
The [complete flake](#flake-parts-adapter) below also works for the first two
layouts: replace its `imports` field with the corresponding `perSystem` block.

## Declarations in flake.nix

For a small project, declare the commands directly in `perSystem`. `inputs`
comes from the enclosing flake-parts module:

```nix
perSystem = { pkgs, ... }:
  let
    tasks = inputs.lexicon.lib.praxis {
      inherit pkgs;
      discoverRoot = "flake.nix";
      commands = {
        fmt = {
          description = "Format the project";
          steps = [ { exec = [ "nix" "fmt" ]; } ];
        };
        test = {
          description = "Run project tests";
          runtimeInputs = [ pkgs.bash ];
          steps = [ { script = "scripts/test.sh"; interpreter = "bash"; forwardArgs = true; } ];
        };
        build = {
          description = "Build a selected flake output";
          parameters = [ { name = "target"; positional = true; default = ".#default"; } ];
          steps = [ { exec = [ "nix" "build" { param = "target"; } ]; forwardArgs = true; } ];
        };
        gate = {
          description = "Format and test the project";
          steps = [ { command = "fmt"; } { command = "test"; } ];
        };
      };
    };
  in {
    apps = tasks.apps;
    packages = tasks.packages // { praxis = tasks.package; };
    devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
  };
```

## One praxis.nix

Keep the commands out of the flake by putting the whole declaration in
`praxis.nix` at the repository root:

```nix
{ praxis, pkgs }:
praxis {
  inherit pkgs;
  discoverRoot = "flake.nix";
  commands = {
    fmt = {
      description = "Format the project";
      steps = [ { exec = [ "nix" "fmt" ]; } ];
    };
    test = {
      description = "Run project tests";
      runtimeInputs = [ pkgs.bash ];
      steps = [ { script = "scripts/test.sh"; interpreter = "bash"; forwardArgs = true; } ];
    };
    build = {
      description = "Build a selected flake output";
      parameters = [ { name = "target"; positional = true; default = ".#default"; } ];
      steps = [ { exec = [ "nix" "build" { param = "target"; } ]; forwardArgs = true; } ];
    };
    gate = {
      description = "Format and test the project";
      steps = [ { command = "fmt"; } { command = "test"; } ];
    };
  };
}
```

The flake's `perSystem` function now contains only wiring:

```nix
perSystem = { pkgs, ... }:
  let
    tasks = import ./praxis.nix { inherit pkgs; praxis = inputs.lexicon.lib.praxis; };
  in {
    apps = tasks.apps;
    packages = tasks.packages // { praxis = tasks.package; };
    devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
  };
```

The `praxis` argument is Lexicon's factory. `pkgs` is the package set for the
current system. Import the file with both; it doesn't read flake inputs or
global variables on its own.

## One file per command

Keep the project settings in one assembly file and return a single command
specification from each command file. Compile the assembled set once, not one
Praxis instance per file. References resolve across those imports.

```text
flake.nix
nix/praxis/
  default.nix
  fmt.nix
  test.nix
  build.nix
  gate.nix
  flake-module.nix
scripts/test.sh
```

`nix/praxis/fmt.nix` returns the command, not `{ fmt = ...; }`:

```nix
{
  description = "Format the project";
  steps = [ { exec = [ "nix" "fmt" ]; } ];
}
```

`nix/praxis/test.nix` takes the package set because it needs Bash:

```nix
{ pkgs }:
{
  description = "Run project tests";
  runtimeInputs = [ pkgs.bash ];
  steps = [ {
    script = "scripts/test.sh";
    interpreter = "bash";
    forwardArgs = true;
  } ];
}
```

`nix/praxis/build.nix` has a positional parameter:

```nix
{
  description = "Build a selected flake output";
  parameters = [ { name = "target"; positional = true; default = ".#default"; } ];
  steps = [ {
    exec = [ "nix" "build" { param = "target"; } ];
    forwardArgs = true;
  } ];
}
```

`nix/praxis/gate.nix` composes the other commands by name:

```nix
{
  description = "Format and test the project";
  steps = [ { command = "fmt"; } { command = "test"; } ];
}
```

`nix/praxis/default.nix` owns project settings and names each imported command:

```nix
{ praxis, pkgs }:
praxis {
  inherit pkgs;
  discoverRoot = "flake.nix";
  commands = {
    fmt = import ./fmt.nix;
    test = import ./test.nix { inherit pkgs; };
    build = import ./build.nix;
    gate = import ./gate.nix;
  };
}
```

Use `import`, not `commands.fmt = ./fmt.nix`. Praxis accepts the resulting
string, step list, or record; it doesn't scan directories or call command
files itself. Give each command one name in the assembly file. If you instead
merge several command sets with `//`, a duplicate name on the right replaces
the entire command, not just its steps.

The [layout check](../../tests/praxis/layouts.nix) compares the normalized
manifests of all three forms. The [per-command fixtures](../../tests/praxis/fixtures/modular)
are also exercised through the runtime CLI.

Strings are Bash source; `exec` is literal argv. Lists run left to right.
`{ command = "test"; }` runs that declaration in place, even if another step
already called it. It isn't a deduplicated dependency. A failed `fmt` skips
`test`. Formatting may already have changed files if `test` subsequently fails.

### Flake-parts adapter

`nix/praxis/flake-module.nix` keeps output wiring out of the command files:

```nix
{ inputs, ... }:
{
  perSystem = { pkgs, ... }:
    let
      tasks = import ./. { inherit pkgs; praxis = inputs.lexicon.lib.praxis; };
    in {
      apps = tasks.apps // {
        praxis = { type = "app"; program = "${tasks.cli}/bin/praxis"; };
      };
      packages = tasks.packages // { praxis = tasks.package; };
      devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
    };
}
```

Import that adapter from the flake-parts module, not from `commands`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.lexicon = {
    url = "github:feltfomo/lexicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    imports = [ ./nix/praxis/flake-module.nix ];
  };
}
```

If your project already defines `devShells.default`, add `tasks.package` to
that shell rather than defining a second one. The adapter exposes a `praxis`
app as well as the direct commands:

```fish
nix run .#praxis -- plan gate
nix run .#build -- .#my-package -- --show-trace
nix develop
praxis run test -- --verbose
```

Use the dispatcher for `test` to avoid the shell builtin with the same name.
Direct executables work too; choose names that don't collide with your shell.
Add new Nix files to Git before using a Git-backed flake, or use `path:.` while
working with an untracked fixture. Praxis doesn't stage files for you.

### Without flake-parts

Keep the per-command files and omit the adapter. In a plain flake's
`outputs = { nixpkgs, lexicon, ... }:`, build a command set for each system:

```nix
let
  tasks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
    import ./nix/praxis {
      pkgs = import nixpkgs { inherit system; };
      praxis = lexicon.lib.praxis;
    });
in {
  apps = builtins.mapAttrs (_: value: value.apps) tasks;
  packages = builtins.mapAttrs (_: value:
    value.packages // { praxis = value.package; }) tasks;
}
```

Only the wiring changes. The command files don't depend on flake-parts,
NixOS, or Home Manager. For the single-file layout, change `import ./nix/praxis`
to `import ./praxis.nix`. For inline declarations, call `lexicon.lib.praxis`
directly in the per-system function instead.

## Arguments without shell interpolation

```nix
commands.build-target = {
  parameters = [
    { name = "target"; positional = true; required = true; }
    { name = "cores"; type = "int"; default = 4; }
  ];
  steps = [ {
    exec = [ "nix" "build" { param = "target"; } "--cores" { param = "cores"; } ];
    forwardArgs = true;
  } ];
};
```

```fish
build-target .#my-package --cores=8 -- --show-trace
praxis plan build-target .#my-package --cores=8
```

`exec` preserves each argv value, including spaces and empty strings. It doesn't
parse shell syntax. Use `run` for pipes or shell logic, and quote values through
`"$PRAXIS_ARG_TARGET"` or `"$@"` rather than splicing them into shell source.
Everything after `--` goes only to the step with `forwardArgs = true`.
Without that step, extra arguments are an error.
A command reference has its own parameter scope. Bind the referenced command
with `args = [ { param = "target"; } ];` for the positional target above. If it forwards
extra arguments, the referenced command must also declare a forwarding step.
Arguments are never broadcast to every step.

## Live scripts and working directories

```nix
commands.verify = {
  runtimeInputs = [ pkgs.bash pkgs.shellcheck ];
  steps = [
    { exec = [ "shellcheck" "ci/check.sh" ]; }
    { script = "ci/check.sh"; interpreter = "bash"; }
  ];
};
```

Create `ci/check.sh` in the runtime directory. `script` reads the live file each
time; changing it doesn't require rebuilding Praxis. Without `interpreter`,
the script needs an executable bit and a valid shebang. Scripts are resolved
just before their step, so an earlier step may generate them. Symlinks are
allowed only when their resolved target stays inside that step's cwd.

With no cwd settings, commands use the caller's directory. `discoverRoot =
"flake.nix";` searches upward from there instead. Command and step cwd overrides
resolve relative to their enclosing scope, never to the Nix store. A child
changing directory or exporting variables does not change the next step.

A different project can also have `flake.nix`. If that ambiguity matters, use
an absolute `cwd`, or enable the [root guard](reference.md#project).
## Run, inspect, and install

```fish
praxis list
praxis show gate
praxis plan gate
praxis run gate
gate --help
gate --plain
praxis completions fish | source
```

`show` prints command help. `plan` emits JSON with expanded steps, argv, cwd,
environment overrides, confirmations, and locks. It does not run a build,
validate a future script's existence, or promise that the commands are harmless.

Use `tasks.package` for the dispatcher and all commands, `tasks.cli` for only the
dispatcher, or `tasks.packages.gate` for one direct executable. Add the
chosen package to `environment.systemPackages`, `home.packages`, or a dev shell.
For persistent fish completion, source the generated completion script in your
fish configuration; `bash` and `zsh` are also accepted by `praxis completions`.

Progress and timings go to stderr. Child stdout and stderr remain live and
unaltered. Colors are disabled for redirected stderr, `--plain`, `NO_COLOR`,
`CI`, or `TERM=dumb`. Interactive children own the terminal while they run.

A lock prevents another Praxis invocation using the same lock name and user
from starting. It doesn't coordinate programs run outside Praxis. `--yes`
accepts declared confirmations; it neither supplies a sudo password nor makes
an interactive program noninteractive. Nothing retries, resumes, or rolls back
a partially completed command.
