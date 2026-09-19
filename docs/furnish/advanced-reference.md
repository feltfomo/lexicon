# Advanced Furnish reference

Most configurations need only `lexicon.lib.furnishRuntime { }` and `lexicon.furnish.declarations`. This page records the compiler integration surface and the currently reachable support machinery without treating every export as an ordinary compatibility promise.

## Support classification

| Surface | Current role |
| --- | --- |
| `lexicon.lib.furnishRuntime { }` | Ordinary NixOS module entry point |
| `lexicon.lib.furnish { inherit resolve resolveSystem; }.compile` | Integration-level compiler entry point |
| `files.mkDeclarations` | Integration helper used by current Program consumers to turn file entries into user declarations |
| `contract` values | Versioned manifest/compiler integration data |
| `core` functions | Reachable and tested support machinery; public stability isn't declared in source |
| returned raw `runtime` | Unbound module constructor requiring runtime dependencies; use the flake-level runtime entry point instead |

The ambiguous exports are exactly `core` and the returned `runtime`: both are deliberately returned by `src/furnish/default.nix`, but neither has a stability annotation or ordinary consumer documentation in the live tree. They are documented as version-sensitive rather than assigned a guarantee the source doesn't state.

## Contract record

<!-- furnish-contract-exports: capabilities conflictPolicies diagnosticSchemaVersion emit executors ledger mkEntry mkFilesystemIdentity runtimeDiagnostics schemaVersion strategies -->

The current `contract` export contains:

- `schemaVersion = 2` and `diagnosticSchemaVersion = 1`;
- `ledger.schemaVersion = 2`, `ledger.fileName = "applied-state.json"`, and `ledger.rollbackFileName = "applied-state.v1.json"`;
- `capabilities` for `symlink`, `writable`, and `lifecycleBaseline`;
- lifecycle `strategies` for exact symlink targets and exact source content;
- the three `conflictPolicies`;
- native `executors`, `runtimeDiagnostics`, `mkFilesystemIdentity`, `mkEntry`, and `emit`.

<!-- furnish-value: contract.values -->
```json
{"capabilities":{"lifecycleBaseline":"lifecycle-baseline","symlink":"symlink","writable":"writable"},"conflictPolicies":{"error":"error","runtimeWins":"runtime-wins","sourceWins":"source-wins"},"diagnosticSchemaVersion":1,"ledger":{"fileName":"applied-state.json","rollbackFileName":"applied-state.v1.json","schemaVersion":2},"schemaVersion":2,"strategies":{"exactSourceContent":"exact-source-content","exactSymlinkTarget":"exact-symlink-target"}}
```

`emit entries` returns `manifestData`, `manifestDocument`, `manifestJson`, and `manifestPath = null`. Runtime materialization replaces the null path with a `pkgs.writeText` result.

`mkFilesystemIdentity { namespace; destination; }` returns `namespace`, `destination`, and `canonical = "${namespace}:${destination}"`. `mkEntry` adds `schemaVersion` to the supplied entry fields.

The native symlink tuple compiled by `furnishRuntime` is:

<!-- furnish-value: runtime.native -->
```json
{"cleanupStrategy":"exact-symlink-target","executor":{"identity":"furnish/native-symlink","protocolVersion":1},"representation":"symlink","schemaVersion":2,"selfHealStrategy":"exact-symlink-target"}
```

The writable tuple uses `furnish/native-writable`, protocol `1`, representation `writable`, and `exact-source-content` for both strategies.

## Compiler result

<!-- furnish-result-fields: manifestData manifestDocument manifestJson manifestPath raw -->

`compile` returns:

- `manifestData`: the ordered list of materialized entries;
- `manifestDocument`: schema version, diagnostic contract, and entries;
- `manifestJson`: JSON encoding of that document with source string context preserved;
- `manifestPath = null`: pure compilation doesn't write the store manifest;
- `raw`: caller data copied through unchanged.

<!-- furnish-value: compiler.empty -->
```json
{"entryCount":0,"manifestPath":null,"raw":{"kept":true}}
```

The exact call shape is:

```nix
furnish.compile {
  declarations = [ ];
  executors = [ ];
  ctx = { };
  raw = { };
  provider = furnish.core.mkEnabledProvider {
    inherit resolve resolveSystem;
  };
}
```

All arguments are optional, but the default provider is the one constructed from the required `resolve` and `resolveSystem` arguments passed to `lexicon.lib.furnish`. Supply `furnish.core.offProvider` when claims must be forbidden explicitly.

An empty declaration list returns an empty emitted manifest and `raw` without selecting a provider or compiling an executor registry. A non-empty list performs shape validation, provider selection, lexical destination derivation, canonical ordering, collision detection, executor selection, and materialization.

## Executor records

An executor record requires:

| Field | Shape |
| --- | --- |
| `identity` | String, unique in the registry |
| `priority` | Integer; lower values sort first |
| `enabled` | Optional Boolean; absent means disabled |
| `protocolVersion` | Integer |
| `capabilities` | List of strings |
| `materialize` | Required value; selected executor must supply a function |

Registry compilation rejects duplicate identities. Enabled candidates must provide both `lifecycle-baseline` and the declaration's representation capability. Selection uses ascending `priority`, then ascending `identity`; no capable executor fails before the source payload is forced.

`materialize declaration` must return:

```nix
{
  retainedArtifactTarget = pathLikeValue;
  cleanupStrategy = "exact-symlink-target";
  selfHealStrategy = "exact-symlink-target";
}
```

The path-like target may be a string, path, or derivation. Both strategy values must be known contract strategies. Runtime executor tuples are stricter: coordinator validation accepts only the two pinned native profiles.

## Providers and Ownerships claims

The enabled provider groups declarations by authority scope. System declarations are selected with `resolveSystem`; user declarations use `resolve`. Surviving declarations have claim keys removed before compilation, and inactive declarations keep `source.value` lazy.

`core.offProvider` is the direct-runtime behavior. Untagged declarations pass through. Any declaration carrying an Ownerships claim fails with `ownership-selection: ownerships-disabled`.

That distinction matters for `lexicon.furnish.declarations`: `furnishRuntime` compiles them with `offProvider`, so optional claim keys aren't supported there. A caller using `lexicon.lib.furnish` with real resolver functions can keep the default enabled provider. Current Program consumers do that upstream; combined authoring belongs in later documentation.

## File declaration helper

<!-- furnish-files-exports: mkDeclarations -->

`files.mkDeclarations` has this call shape:

```nix
furnish.files.mkDeclarations {
  filesystemNamespace = "x86_64-linux/studio";
  principals = [ ... ];
  files = [
    {
      src = ./settings.conf;
      dest = ".config/paperkite/settings.conf";
    }
  ];
}
```

`files` defaults to `[ ]`. The helper emits one declaration per file for each supplied user principal and emits nothing for system principals. A principal may set `managedRoot`; otherwise it defaults to `/home/${authority.identity}`.

Each file requires `src` and `dest`. Optional fields are `label`, `representation`, `onConflict`, and `provenance`. Defaults are `label = "files[${dest}]"`, representation `symlink`, and no explicit conflict policy. The source becomes `{ kind = "path"; value = src; }`. The helper doesn't accept Ownerships claim fields itself.

<!-- furnish-value: helper.generated -->
```json
{"authority":{"identity":"river","scope":"user"},"count":1,"destination":".config/paperkite/settings.conf","label":"files[.config/paperkite/settings.conf]","managedRoot":"/home/river","representation":"symlink","sourceKind":"path"}
```

## Exported core support

<!-- furnish-core-exports: buildHostIndex collisionDiagnostics compile deriveDestination diagnostic indexProjection isOwnerTagged mkEnabledProvider offProvider projectPrincipal renderDiagnostic renderDiagnostics selectExecutor shapeDiagnostics validateExecutors validateShape -->

The current `core` record exports:

- `compile`, `validateShape`, `shapeDiagnostics`, and `validateExecutors`;
- `mkEnabledProvider`, `offProvider`, `isOwnerTagged`, and `projectPrincipal`;
- `deriveDestination`, `indexProjection`, `collisionDiagnostics`, and `buildHostIndex`;
- `selectExecutor`;
- `diagnostic`, `renderDiagnostic`, and `renderDiagnostics`.

These functions expose internal compiler boundaries directly. Their exact signatures are tested by current source, but no public stability tier is declared. Use `compile` through the top-level returned attribute when possible; pin Lexicon before depending on the rest.

## Raw runtime export

The `runtime` attribute returned by `lexicon.lib.furnish` is the unbound function from `src/furnish/runtime.nix`. Its current import-time dependencies are:

```nix
import ./runtime.nix {
  inherit mkCoordinator krisis axiom;
}
```

After those dependencies are supplied, it is a NixOS module. Ordinary consumers should not reconstruct that binding; `lexicon.lib.furnishRuntime { }` supplies the pinned coordinator, Krisis, and Axiom dependencies from the Lexicon flake.

## Current source-kind boundary

Shape validation requires `source.kind` to be a string and deliberately leaves `source.value` unforced. The native runtime executors don't dispatch on `source.kind`; they materialize `source.value` as a path-like source. `files.mkDeclarations` therefore emits `kind = "path"`.

A custom executor can interpret additional source metadata, but the current compiler doesn't define a registry of source kinds. Treat non-`path` values as part of that custom, version-sensitive integration rather than built-in Furnish support.

## Ordering and collisions

Selected declarations are normalized and sorted by canonical filesystem identity before materialization. Collision reporting uses canonical identity and sorts claimants by authority scope, authority identity, provenance source, and declaration label.

`buildHostIndex` and `projectPrincipal` expose pre-materialization projections for integration checks. They use the provider to select only declarations matching each principal authority. They don't create a runtime manifest.

`selectExecutor` validates and orders a supplied registry before returning the first capable executor. Materialization remains lazy until selection, so an unusable executor or inactive declaration doesn't need to force the source payload.

[Back to Furnish](README.md) · [Reference](reference.md) · [Runtime and safety](runtime.md)
