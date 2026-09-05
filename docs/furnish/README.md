# Furnish

Furnish manages declared files on a machine. Its Nix compiler produces a
desired-state manifest; the Furnish coordinator reconciles that manifest with
the filesystem and an applied-state ledger.

Use it directly in NixOS for managed files, or let Program translate application
file entries into Furnish declarations. Program is an optional authoring layer,
not a prerequisite.

## Pick a representation and policy

| Representation | Result |
| --- | --- |
| `symlink` | A link to immutable source content |
| `writable` | A real file the application can modify |

For writable files, choose what should happen when runtime content differs
from the recorded baseline:

- `error` stops reconciliation on a conflict.
- `source-wins` restores the declared content.
- `runtime-wins` preserves the current runtime content.

The ledger records applied state. It can detect divergence; it cannot tell
whether a person or an application made a particular edit.

## Guides

- [Usage](USAGE.md): standalone NixOS wiring, declarations, and pure compilation.
- [Declaration contract](declaration-contract.md): authority, paths, sources, executors, and lifecycle fields.
- [Runtime integration](runtime-integration.md): activation, services, durable state, and coordinator behavior.
- [Architecture](architecture.md): validation, selection, collision checking, and manifest generation.

## What the compiler checks

Furnish validates declaration shapes, selects active ownership claims,
normalizes destinations, checks host-wide collisions, chooses an executor,
and emits the manifest. It does not mutate the filesystem during evaluation.
Inactive ownership payloads and unused executors remain lazy.

Two declarations cannot claim the same filesystem destination, even if their
content is identical. Each destination must remain beneath its managed root.
An enabled runtime still emits an empty manifest when all declarations are
removed, so the coordinator can retire previously managed content.

## Public API

`inputs.lexicon.lib.furnish` takes `resolve` and `resolveSystem` along with
optional dependency overrides. It exports `compile`, `contract`, `core`, and
`files.mkDeclarations`. Use `inputs.lexicon.lib.furnishRuntime { }` to obtain
the NixOS module with Lexicon's coordinator dependency wired in.

The coordinator is a separate package. Its reconciliation, recovery, and
ledger implementation are not duplicated in the Nix library.
