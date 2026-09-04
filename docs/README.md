# Lexicon

Lexicon is three layers. Each one is a usable library on its own, and each one
is useful without the layers above it.

| Layer | What it decides | Reach for it when |
| --- | --- | --- |
| **Ownerships** | which configuration applies to which host and user, and how the survivors merge | you want host and user targeting for plain Nix values |
| **Furnish** | what files should exist on a machine, and how they are kept that way | you want managed files with a real lifecycle, not just store symlinks |
| **Program** | all of the above, from one declaration | you are declaring an aspect |

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

## Documentation

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

## Verification

```fish
nix fmt
nix flake check -L
```
