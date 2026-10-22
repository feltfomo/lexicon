# Furnish API

`inputs.lexicon.lib.furnish { resolve, resolveSystem }` returns `compile`,
`contract`, `core`, `files`, `runtime`. `runtime` is a constructor requiring
`{ mkCoordinator, krisis, axiom }`, then a NixOS module. The flake export
`inputs.lexicon.lib.furnishRuntime {}` supplies those dependencies and returns
the module directly. `inputs.lexicon.lib.mkCoordinator { pkgs }` returns the
coordinator package.

## Pure compilation

`compile { declarations ? [], executors ? [], ctx ? {}, raw ? {},
provider ? defaultOwnershipProvider }` returns:

| Field | Value |
| --- | --- |
| `manifestData` | Ordered list of compiled entries |
| `manifestDocument` | `{ schemaVersion, diagnosticContract, entries }` |
| `manifestJson` | JSON string of that document |
| `manifestPath` | null; pure compilation does not materialize a manifest file |
| `raw` | Caller-supplied value preserved verbatim |

Empty declarations emit an empty manifest without forcing executors, context
or ownership provider. Compilation validates shapes, selects ownership,
normalizes destinations, rejects collisions and materializes selected entries.

## Declarations

| Field | Type / requirement |
| --- | --- |
| `label` | Required string |
| `filesystemNamespace` | Required string, normally canonical host ID |
| `authority` | Required `{ scope, identity }`; scope `"user"` or `"system"`, identity string |
| `managedRoot` | Required absolute path string |
| `destination` | Required string, relative to root or absolute beneath it |
| `representation` | Required non-empty capability name |
| `source` | Required `{ kind = string; value = source; }`; value remains lazy during shape validation |
| `onConflict` | `"error"`, `"source-wins"`, `"runtime-wins"`; default `"error"` |
| `provenance` | Optional attribute set of strings; `source` supplies the source label |
| Ownership claims | Default claim vocabulary from ownerships |

System authority identity must contain `/` and represent `system/name`.
Destination and root are lexically normalized. Root `/`, the root itself as a
destination, traversal escaping the root and paths outside the root are rejected.
Filesystem identity is `{ namespace, destination, canonical }`; canonical key
is `"${namespace}:${absoluteDestination}"`. Duplicate keys fail regardless of
authority, equal content or conflict policy.

Compiled entries contain `schemaVersion`, `filesystemIdentity`, `authority`,
normalized `managedRoot`, `onConflict`, `representation`, `target = { kind, path }`, `executor = { identity, protocolVersion }`,
`cleanupStrategy`, `selfHealStrategy`, and
`provenance = { declaration, source }`.

## Executors and providers

An executor requires string `identity`, integer `priority`, integer
`protocolVersion`, string list `capabilities`, and `materialize`.
`enabled` is an optional boolean, default false. Identities must be unique.
Selection requires both `"lifecycle-baseline"` and the declaration's
`representation`. Lower priority wins; identity sorts ties.

The selected `materialize` must be `declaration: artifact`, returning
`target = { kind = "retained"; path = source; }` or
`target = { kind = "external"; path = absoluteString; }`, `cleanupStrategy` and
`selfHealStrategy`. Strategies are `"exact-symlink-target"` or
`"exact-source-content"`.

A provider supplies `isOwnerTagged` and
`selectApplicable = declarations: ctx: selectedDeclarations`.
`core.mkEnabledProvider { resolve, resolveSystem }` performs ownership selection
by authority scope. `core.offProvider` accepts unclaimed declarations and
rejects any ownership claim.

## File adapter

`files.mkDeclarations { filesystemNamespace, principals, files ? [], links ? [] }` converts
program-style `{ src, dest, label?, representation?, onConflict?, provenance? }`
entries to declarations for each supplied user principal. System principals
are ignored. A principal requires `authority`; optional `managedRoot` defaults
to `"/home/${authority.identity}"`. Representation defaults to `"symlink"`;
file sources become `{ kind = "path"; value = src; }`.
The optional `links` list accepts `{ target, dest, label?, provenance? }` and
emits `{ kind = "external"; value = target; }` with the symlink representation. This adapter does not select
file ownership claims; callers select files first.

## NixOS options

These options live under `lexicon.furnish`.

| Option | Type | Default / meaning |
| --- | --- | --- |
| `enable` | Boolean | false |
| `declarations` | List of attribute sets | `[]`; already selected for this host, claims rejected by the runtime |
| `state.path` | String | `"/var/lib/furnish"`; ledger directory |
| `state.durability` | `"durable"` or `"ephemeral"` | `"ephemeral"`; durability assertion, does not arrange persistence |
| `state.requiresMountsFor` | String list | `[]`; additional mount dependencies |
| `manifestData` | Read-only list of attribute sets | Compiled entries |
| `manifestPath` | Read-only path or null | Store manifest when enabled; null when disabled |
| `ledgerPath` | Read-only string | `"${state.path}/applied-state.json"` |

Bundled executors provide `symlink` and `writable`, both with priority 0 and
protocol version 1. `symlink` uses exact symlink target checks; `writable` uses
exact source content checks. Path sources are retained using `builtins.path`. External sources remain literal
strings, need not exist and are valid only for symlinks.

Enabled reconciliation runs after users during ordinary activation and at boot
through `furnish.service`, after local filesystems and required destination/state
mounts. Initrd-marked activation defers reconciliation to that service. Enabled
empty manifests reconcile retirements. Disabled runtime installs no activation
or service, even though its pure `manifestData` is computed.

`error` refuses conflicting runtime state; `source-wins` selects declared source
content; `runtime-wins` retains runtime content on divergence. These policies
do not remove the coordinator's ownership, transition or recovery checks.
The applied-state ledger must survive wherever lifecycle ownership needs to
survive. Durable storage and its mount ordering belong to the consuming host.

## Contract and core helpers

`contract` exposes `schemaVersion = 3`, `diagnosticSchemaVersion = 1`,
`ledger = { schemaVersion = 2; fileName = "applied-state.json";
rollbackFileName = "applied-state.v1.json"; }`, `capabilities`, `strategies`,
`conflictPolicies`, `executors`, `runtimeDiagnostics`.
Capabilities are `symlink`, `writable`, `lifecycleBaseline` with string values
`"symlink"`, `"writable"`, `"lifecycle-baseline"`.
Executor contracts are `nativeSymlink` and `nativeWritable`, with identities
`"furnish/native-symlink"` and `"furnish/native-writable"`.

| Function | Signature / result |
| --- | --- |
| `contract.mkFilesystemIdentity` | `{ namespace, destination }`: identity record |
| `contract.mkEntry` | Compiled entry fields: entry tagged with schema version |
| `contract.emit` | `entries`: manifest fields, with null path |
| `core.compile` | Same as top-level `compile` |
| `core.validateShape` | `declaration`: shape-checked declaration, or throw |
| `core.shapeDiagnostics` | `declaration`: diagnostic list |
| `core.validateExecutors` | `executors`: validated list, or throw |
| `core.isOwnerTagged` | `declaration`: boolean |
| `core.deriveDestination` | `declaration`: normalized declaration plus filesystem identity |
| `core.indexProjection` | Normalized declaration: identity, authority, root, provenance |
| `core.collisionDiagnostics` | `projections`: diagnostic list |
| `core.projectPrincipal` | `{ declarations, principal, provider ? defaultProvider }`: selected index projections; principal has `authority` and `ctx` |
| `core.buildHostIndex` | `{ declarations ? [], principals ? [], provider ? defaultProvider }`: canonical key to projection, or throw on collision |
| `core.selectExecutor` | `executors: declaration: selectedExecutor` |
| `core.diagnostic` | `stage: code: entryLabel: reason: diagnostic` |
| `core.renderDiagnostic`, `core.renderDiagnostics` | One diagnostic or list: rendered string |

## Runtime compatibility and output

Manifest schema 3 replaces `retainedArtifactTarget` with a tagged `target`.
Both target kinds use the existing symlink executor; writable entries require
a retained target. The coordinator also accepts schema 2 as retained sources.
The ledger is unchanged by source retention semantics.

Activation and `furnish.service` select `--diagnostic-format plain`, so warnings
and refusals render readable severity, code, destination and explanation.
Direct coordinator invocations retain JSON output by default. Runtime
presentation belongs to the coordinator; Krisis renders evaluation diagnostics.
