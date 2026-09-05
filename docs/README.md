# Lexicon

Lexicon provides four libraries for Nix projects. Use them independently or
connect them where their responsibilities meet.

| Library | Use it for | Start here |
| --- | --- | --- |
| Ownerships | Select and merge configuration for a host, user, or custom axis | [Ownerships](ownerships/README.md) |
| Furnish | Declare managed files and reconcile their on-disk state | [Furnish](furnish/README.md) |
| Program | Package an application's modules, files, directories, and theme as an aspect | [Program](program.md) |
| Praxis | Package project commands with typed inputs and an execution policy | [Praxis](praxis.md) |

## Choose a starting point

**Selecting configuration.** Define a roster and resolve ownership-tagged units.
Ownerships returns values; it doesn't install packages, write files, or execute
commands. Start with [standalone resolution](ownerships/USAGE.md).

**Managing files.** Furnish compiles declarations into a desired-state manifest
and offers NixOS wiring for the coordinator that applies it. Use `symlink` for
immutable content or `writable` when an application needs a real file. Start
with [Furnish usage](furnish/USAGE.md) and choose a conflict policy deliberately.

**Describing an application.** Program gathers package selection, Home Manager
imports, NixOS slices, files, directory expansion, and generated themes into
an aspect. It uses Ownerships for selection and Furnish for managed files.
[Program usage](program.md) shows the declaration and the required integration
context.

**Running project work.** Praxis compiles commands into launchers and a
`praxis` dispatcher. It does not require Program, Furnish, Ownerships, or Den.
Start with [a small command set](praxis/usage.md), then add
[interaction policies](praxis/interaction.md) where needed.

## Connections between libraries

- Program uses Ownerships claims to choose application configuration.
- Program lowers selected file entries into Furnish declarations.
- Furnish can use Ownerships resolvers directly, without Program.
- A Lexicon Den adapter supplies roster and principal context to these
  libraries. Den's internal configuration is not a Praxis or Furnish API.
- Praxis can use an Ownerships roster or an existing Den adapter to populate
  [parameter choices](praxis/adapters.md). Those choices do not authorize an
  operation or make Praxis a fleet controller.

The public factories live under `inputs.lexicon.lib`. They supply Lexicon's
Axiom and Krisis dependencies. Prefer them in consumer flakes; direct imports
from `src/` require those dependencies to be supplied explicitly.

## Working on Lexicon

Run from the checkout root, using the appropriate system in place of
`x86_64-linux`:

```fish
nix run path:.#formatter.x86_64-linux
and nix flake check path:. -L
```

`path:.` includes newly created files before staging. Checks build and test
artifacts; they do not activate a host configuration. Host activation and
release publication are separate operations.

The development shell includes the Nix and Rust tooling used by the checks:

```fish
nix develop path:.
```

Axiom and Krisis use Nix pipe operators. If your Nix version asks for the
feature, enable `pipe-operators` for that invocation or in your own Nix
configuration. Do not treat unrelated flake configuration as implicitly trusted.
