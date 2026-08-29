# Furnish

Furnish compiles file declarations into a deterministic desired-state manifest,
and wires that manifest into NixOS activation. Nix proves the manifest is
well-formed; a Rust coordinator applies it on the machine.

It is the machinery behind `program.files` and `program.directories`. Reach for
it directly when you want managed files without the aspect layer — see
[Usage](USAGE.md).

The reason it exists rather than a pile of `home.file` entries is the
`writable` representation. A store symlink is immutable, which is wrong for any
config file the application itself rewrites. Furnish can install real, writable
content and still tell you later whether it drifted.

This documentation covers the Nix boundary only. The coordinator's
reconciliation algorithms, crash recovery, and ledger implementation belong to
a separate pass.

## Responsibilities

The Nix layer owns the versioned manifest and diagnostic contract, declaration
validation, Ownerships-backed selection, destination normalization, host-wide
collision detection, executor validation and capability selection, retained
artifact materialization, manifest emission, and NixOS activation wiring.

It deliberately performs no filesystem mutation during evaluation.

## Data flow

```text
Program file entries
→ principal-aware Furnish declarations
→ shape validation
→ ownership selection
→ destination normalization
→ collision index
→ executor selection
→ artifact validation
→ manifest JSON
→ furnish-coordinator reconcile
```

## Documentation

- [Usage](USAGE.md) — standalone compile, writable files, runtime wiring
- [Architecture](architecture.md) — the pipeline and its stages
- [Declaration contract](declaration-contract.md) — every field
- [Runtime integration](runtime-integration.md) — activation, service, ledger

## Public surface

`src/furnish/default.nix` takes `resolve` and `resolveSystem` from Ownerships
and exports:

| Export | Role |
| --- | --- |
| `compile` | Compile declarations and executors into manifest projections. |
| `contract` | Versioned constants and manifest constructors. |
| `core` | Validation, selection, indexing, diagnostics, and test seams. |
| `files.mkDeclarations` | Lower selected home-relative file entries to declarations. |
| `runtime` | NixOS module import. |

Only `files.mkDeclarations` and the runtime module are used by Program. Most
`core` exports exist for internal composition and tests.

## Invariants

- No declaration is silently selected when Ownerships is disabled.
- Inactive ownership payloads are not forced.
- Every managed destination stays lexically beneath its managed root.
- Filesystem identity is canonical before collision detection.
- Collisions fail with all claimants; source order never chooses a winner.
- Executor ordering is deterministic by priority and identity.
- Unselected executor implementations remain lazy.
- Every manifest entry names its conflict policy and lifecycle strategies.
- An enabled runtime emits an empty manifest when there are no declarations, so
  retirement can still occur.

## Verification

```fish
nix fmt
nix flake check -L
```
