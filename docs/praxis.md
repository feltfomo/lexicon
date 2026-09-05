# Praxis

Praxis packages a project's commands as Nix apps and executables. Each command
is an ordered sequence of shell scripts, literal executable calls, live script
files, prompts, or references to other commands.

```nix
let
  tasks = inputs.lexicon.lib.praxis {
    inherit pkgs;
    commands = {
      fmt = "nix fmt";
      test = "nix flake check -L";
      check = {
        description = "Format and test the project";
        lock = "project-check";
        steps = [
          { command = "fmt"; }
          { command = "test"; }
        ];
      };
    };
  };
in
{
  packages = tasks.packages // { praxis = tasks.package; };
  apps = tasks.apps // {
    praxis = { type = "app"; program = "${tasks.cli}/bin/praxis"; };
  };
}
```

This example belongs inside a per-system output where `pkgs` and `inputs` are
available. [Usage](praxis/usage.md) includes complete output wiring and ways to
split command declarations across files.

```fish
nix run .#praxis -- list
nix run .#praxis -- show check
nix run .#praxis -- plan check --plain
nix run .#check
```

A command runs from the caller's working directory unless you configure a
working directory or root-discovery policy. Each executable step gets a fresh
process. References preserve their order and repetitions; they are not
parallel dependencies. Failure stops later steps without rolling back earlier
ones.

## Guides

- [Usage](praxis/usage.md): packaging, scripts, references, arguments, and inspection.
- [Interaction](praxis/interaction.md): choices, prompts, conditions, UI, notifications, and timeouts.
- [Reference](praxis/reference.md): declaration fields and output attributes.
- [Security](praxis/security.md): runtime credentials, shell boundaries, roots, and cancellation.
- [Roster adapters](praxis/adapters.md): optional Ownerships and Den inputs.
- [Architecture](praxis/architecture.md): evaluation and execution boundaries.
- [Runtime dependencies](praxis/dependencies.md): evaluated CLI, terminal, progress, and notification libraries.

## Inspection before execution

`show` displays a command's declaration, parameters, prompts, locks, examples,
and metadata. `plan` binds arguments and expands references without running
steps. It defaults to JSON for scripts; `--plain` and `--verbose` select human
output. `doctor` checks the project root and current executable, directory,
and script availability without running the command.

Use `--non-interactive` for unattended work and add `--yes` only when accepting
confirmations is intended. Typed acknowledgement is never bypassed by
`--yes`. Read the [prompt policy](praxis/interaction.md#prompt-steps) before
putting a command in CI.
