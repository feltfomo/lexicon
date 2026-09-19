# Furnish

Furnish declares files in a NixOS configuration, exposes the compiled desired state for review, and can reconcile that state during activation and boot. Use it when a file should be a store-backed symlink or a writable copy whose runtime edits need an explicit conflict policy.

You can evaluate every example in this section without activating a machine. Evaluation may add source artifacts to the Nix store, but it doesn't write the declared destinations.

## Choose a path

1. [Getting started](getting-started.md) evaluates one complete managed-file declaration, makes a predictable edit, and moves the same files into an ordinary consumer flake.
2. [Usage](usage.md) solves focused tasks: representations, conflict policy, authority, paths, state, inspection, and diagnostics.
3. [Worked example](worked-example.md) combines several Furnish declarations for one fictional application without adding another Lexicon system.
4. [Reference](reference.md) is the lookup page for declarations, compiler results, helper calls, and NixOS options.
5. [Runtime and safety](runtime.md) explains activation, boot reconciliation, the applied-state ledger, retirement, and state loss.
6. [Advanced reference](advanced-reference.md) records contract constants, executor/provider machinery, and exports whose support status is narrower or version-sensitive.

## Runnable examples

| Scale | Directory | What it shows |
| --- | --- | --- |
| Minimal | [examples/furnish](../../examples/furnish/) | One user-owned symlink and a projected manifest result |
| Focused | [examples/furnish-policies](../../examples/furnish-policies/) | Symlink and writable files with all three conflict-policy outcomes represented |
| Larger | [examples/furnish-studio](../../examples/furnish-studio/) | User and system authority in one coherent Paperkite configuration |

Each example directory is a complete flake.

## Before activation

Read [runtime and safety](runtime.md) before enabling Furnish on an existing host. A successful evaluation proves that declarations compile and that their manifest can be built. It doesn't prove that a destination is free, that a user account exists on the running machine, or that the ledger is durably stored.

Furnish records what it has applied in `applied-state.json`. Keep that state persistent on hosts whose root is replaced, and don't delete it as a way to clear a conflict.

[Back to the Lexicon manual](../README.md) · [Examples](../../examples/README.md)
