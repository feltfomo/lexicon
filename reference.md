# Lexicon API reference

This reference describes the public API on `main`. All constructors below are
attributes of `inputs.lexicon.lib`. An argument named `spec` is a Nix attribute
set. Curried arguments are applied from left to right.

| API | Arguments | Result | Reference file |
| --- | --- | --- | --- |
| `toml` | `{ pkgs, lib ? pkgs.lib }` | TOML generation, typed values, document merge and publisher package | `src/toml/reference.md` |
| `ownerships` | `{ descriptors ? null, relations ? null, ... }` | Ownership API | `src/ownerships/reference.md` |
| `registry` | Fleet declaration | Fleet records and lookups | `src/registry/reference.md` |
| `den` | `{ den, ... }` | Den adapter | `src/den/reference.md` |
| `program` | `{ resolve, resolveSystem, resolvePrepared, filePrincipals, hostUserNames, ... }`, then `spec` | Aspect with optional `homeManager` and `nixos` modules | `src/program/reference.md` |
| `programDirect` | `{ target, ... }`, then `spec` | Program bound to one explicit target | `src/program/reference.md` |
| `programOwnerships` | `{ roster, ... }`, then `spec` | Program using ownership selection | `src/program/reference.md` |
| `programDen` | `{ den, ... }`, then `spec` | Program using Den's roster and file principals | `src/program/reference.md` |
| `furnish` | `{ resolve, resolveSystem, ... }` | Pure file declaration compiler | `src/furnish/reference.md` |
| `furnishRuntime` | `{ ... }` | NixOS module for file reconciliation | `src/furnish/reference.md` |
| `praxis` | Command project declaration including `pkgs` | Packages, apps, checks and runtime metadata | `src/praxis/reference.md` |
| `praxisAdapters` | `{ lib ? nixpkgs.lib }` | `fromRoster` and `fromDen` parameter adapters | `src/praxis/reference.md` |
| `report` | `{ ... }` | Program diagnostic helpers | `src/program/reference.md` |
| `mkCoordinator` | `{ pkgs }` | Furnish coordinator package | `src/furnish/reference.md` |

Program theme fields are specified in `src/program/theme/reference.md`.

Except for `mkCoordinator` and `toml`, constructors accept dependency overrides. `lib`
defaults to the flake's nixpkgs library; `axiom` and `krisis` default to the
flake's inputs instantiated with that library. Program constructors and
`furnishRuntime` also accept `mkCoordinator` as an override.

`program` has an optional internal `binding` argument. Consumer declarations
use `programDirect`, `programOwnerships`, or `programDen` for bound APIs.
`praxis` has an internal `_prepareOnly` argument; it is outside the consumer API.

Lexicon exports library constructors, not a Den flake module. A program result
contains module attributes; a Praxis result contains flake output attributes.
