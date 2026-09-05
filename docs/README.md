# Lexicon

Lexicon adds declarative vocabulary to Nix through independently usable
subsystems. Ownerships, Furnish, and Program form the configuration stack.
Praxis sits alongside them as a command utility, not a fourth layer. Declare a
sequence once, then run it through one executable. Start with [Praxis](praxis.md)
or go straight to [usage](praxis/usage.md) and the [reference](praxis/reference.md).

| Subsystem | What it decides | Reach for it when |
| --- | --- | --- |
| **Ownerships** | which configuration applies to which host and user, and how the survivors merge | you want host and user targeting for plain Nix values |
| **Furnish** | what files should exist on a machine, and how they are kept that way | you want managed files with a real lifecycle, not just store symlinks |
| **Program** | all of the above, from one declaration | you are declaring an aspect |
| **Praxis** | which project commands run, in what order, and when they fail | you want `nix run .#gate` from a declarative command set |

## Add it to a flake

```nix
inputs.lexicon = {
  url = "github:feltfomo/lexicon";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

That one input carries Axiom, Krisis, and Furnish Coordinator. Consumers don't
add or align those repositories themselves. Lexicon binds them behind its
`lib` functions while still accepting explicit overrides for fixtures.

## Which one do I want

**Program** is the abstraction over the other two. One `program { ... }` block
becomes ownership units, a Home Manager module, a NixOS module, and Furnish
declarations. If its vocabulary covers what you are declaring, stop there — you
get the validation and the diagnostics for free.

```nix
den.aspects.hyprland = program {
  hosts = [ "khion" "lumi" ];
  pkg = pkgs: pkgs.pyprland;
  nixos = { pkgs, ... }: [ ... ];
  files = [ ... ];
};
```

**Ownerships** on its own is the right tool when you have plain Nix values that
differ per machine or per person. It has no opinion about NixOS, Home Manager,
or files. You hand it units and a context, it hands you one merged value.

```nix
resolve [
  { shared = true; }
  { hosts = [ "khion" ]; desktop = true; }
] { host = { name = "khion"; system = "x86_64-linux"; }; user.name = "feltfomo"; }
```

**Furnish** on its own is the right tool when the interesting part is the file,
not the targeting. Its reason to exist is the `writable` representation — a
file the application is allowed to rewrite, tracked against a ledger so the
next rebuild knows whether the change came from you or from the app.

## How they stack

```text
program declaration
  → ownership units          (who gets this)
  → resolved per host/user   (what applies here)
  → furnish declarations     (which files should exist)
  → manifest                 (handed to the coordinator)
```

Each arrow is a boundary you can enter at. Program enters at the top, a
standalone NixOS config can enter at ownership units, and a tool that already
knows its file list can enter at furnish declarations.

Praxis doesn't enter this stack. It turns a project's `commands` into apps and
packages while leaving host configuration and file lifecycles alone.

## Documentation

**Praxis**

- [Praxis](praxis.md) — declare several commands and run them as one
- [Usage](praxis/usage.md) — three declaration layouts, arguments, scripts, and installation
- [Reference](praxis/reference.md) — declaration fields, outputs, and CLI
- [Architecture](praxis/architecture.md) — runner, migration, and checks

**Program**

- [Program](program.md) — the declaration vocabulary and what it emits

**Ownerships**

- [Overview](ownerships/README.md)
- [Usage](ownerships/USAGE.md) — standalone, NixOS, and Home Manager
- [Doors](ownerships/doors.md) — the resolver carrier and the generated names
- [Architecture](ownerships/architecture.md)
- [Merge and provenance](ownerships/merge-and-provenance.md)
- [Rosters and extension](ownerships/rosters-and-extension.md)
- [Trace and matrix inspection](ownerships/inspection.md)
- [Reference](ownerships/reference.md)

**Furnish**

- [Overview](furnish/README.md)
- [Usage](furnish/USAGE.md) — standalone compile and writable files
- [Architecture](furnish/architecture.md)
- [Declaration contract](furnish/declaration-contract.md)
- [Runtime integration](furnish/runtime-integration.md)

## Shared runtime machinery

Axiom supplies reusable runtime types, accumulating validation, parser-backed
schema fields, stable string sets, and indexed requirements/phases. Krisis adds
path-aware type diagnostics, safe summaries, and a shared spelling suggester.
Praxis consumes these boundaries; Furnish and Ownerships retain their existing
authority, selection, and merge contracts. The Axiom `language/` implementation
is not used by these additions.

Shared source uses `|>`. Nix 2.25 needs `extra-experimental-features = pipe-operators`
(plural), or acceptance of the flake's setting. Raw source imports and consuming
flakes must enable the feature at their own entry point. The tested Lix version
supports pipes directly. See [coordinated local development](local-development.md)
for checking unpublished Axiom/Krisis changes without modifying dependency locks.

## Verification

```fish
nix fmt
nix flake check -L
```

Or use the same steps through Praxis: `nix run .#gate`. The repository also
exposes `nix run .#fmt` and `nix run .#test` individually.
