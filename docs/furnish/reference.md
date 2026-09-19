# Furnish reference

This page covers the ordinary authoring and inspection surface. See [advanced reference](advanced-reference.md) for contract records, custom providers and executors, and version-sensitive exports.

## Flake entry points

<!-- furnish-flake-exports: furnish furnishRuntime -->

`lexicon.lib.furnishRuntime { }` returns the NixOS module used by ordinary Furnish configurations:

```nix
{
  imports = [ (lexicon.lib.furnishRuntime { }) ];
}
```

`lexicon.lib.furnish` is a library constructor. It currently requires both ownership resolver functions:

```nix
lexicon.lib.furnish {
  inherit resolve resolveSystem;
}
```

It returns these top-level attributes:

<!-- furnish-exports: compile contract core files runtime -->

- `compile` compiles declarations with caller-supplied executors.
- `contract` contains manifest constants and constructors.
- `files` contains the `mkDeclarations` authoring helper.
- `core` exposes compiler support functions.
- `runtime` is the raw unbound module constructor; prefer `lexicon.lib.furnishRuntime { }`.

## NixOS options

<!-- furnish-options: declarations enable ledgerPath manifestData manifestPath state.durability state.path state.requiresMountsFor -->

| Option | Type | Default | Read-only | Meaning |
| --- | --- | --- | --- | --- |
| `lexicon.furnish.enable` | Boolean | `false` | No | Add manifest materialization and reconciliation entry points |
| `lexicon.furnish.state.path` | String | `/var/lib/furnish` | No | Directory containing the applied-state ledger |
| `lexicon.furnish.state.durability` | `"durable"` or `"ephemeral"` | `"ephemeral"` | No | Host claim about whether state survives a root wipe; it doesn't configure persistence |
| `lexicon.furnish.state.requiresMountsFor` | List of strings | `[ ]` | No | Extra paths passed to the boot service's mount ordering |
| `lexicon.furnish.declarations` | List of attribute sets | `[ ]` | No | Direct declarations compiled by the runtime's built-in off provider |
| `lexicon.furnish.manifestData` | List of attribute sets | Computed | Yes | Compiled manifest entries, available even while disabled |
| `lexicon.furnish.manifestPath` | Null or path | Computed | Yes | Materialized manifest when enabled; `null` while disabled |
| `lexicon.furnish.ledgerPath` | String | Computed | Yes | `${state.path}/applied-state.json` |

`state.requiresMountsFor` doesn't create, mount, or persist anything. Destination paths are added to `RequiresMountsFor` automatically; use the option for extra backing paths such as `/persist`.

## Declaration fields

A direct declaration is an attribute set with these required fields:

| Field | Accepted shape | Meaning and restrictions |
| --- | --- | --- |
| `label` | String | Diagnostic label; empty strings pass shape validation but aren't useful |
| `filesystemNamespace` | String | Stable namespace used with the absolute destination to form canonical identity |
| `authority` | Attribute set | Contains `scope` and `identity` |
| `managedRoot` | String | Absolute, non-root management boundary after normalization |
| `destination` | String | Absolute or relative path; the normalized result must be strictly below `managedRoot` |
| `representation` | Non-empty string | Built-in runtime supports `"symlink"` and `"writable"` |
| `source` | Attribute set | Contains required `kind` and lazy `value` |

Optional fields:

| Field | Accepted shape | Default or effect |
| --- | --- | --- |
| `provenance` | Attribute set whose values are strings | Manifest source defaults to `label`; ordinary diagnostics use `provenance.source` |
| `onConflict` | `"error"`, `"source-wins"`, or `"runtime-wins"` | `"error"` |
| Ownership claim keys | Current Ownerships claim vocabulary | Accepted only when compilation uses an enabled provider; direct runtime declarations reject them |

Unknown top-level fields are currently accepted so declarations can carry claim and caller metadata. Don't treat acceptance as a promise that unknown fields reach the manifest.

### `authority`

| Field | Rule |
| --- | --- |
| `scope` | Required; exactly `"user"` or `"system"` |
| `identity` | Required string; system identities must contain `/` and normally use `<system>/<name>` |

At runtime, user identity must resolve to an account and primary group. System authority runs the native worker directly.

### `source`

`source.kind` is required and only shape-checked as a string by the compiler. The built-in helper emits `"path"`; the native runtime materializers read `source.value` as a path-like source artifact. Other kinds require custom executor semantics and aren't an ordinary runtime guarantee.

`source.value` is required but remains lazy during shape validation and Ownerships selection. A declaration filtered out by an enabled provider doesn't force its payload.

## Path normalization and identity

Relative destinations are joined to `managedRoot`. Both paths are normalized lexically: empty and `.` components collapse, `..` removes one component, and an escape fails. The final destination must be an absolute strict descendant of a non-root `managedRoot`.
`filesystemIdentity` is derived, not authored. It contains:

```nix
{
  namespace = filesystemNamespace;
  destination = absoluteDestination;
  canonical = "${filesystemNamespace}:${absoluteDestination}";
}
```

Compiled entries are sorted by `filesystemIdentity.canonical`. Duplicate canonical identities fail with all claimants named. The runtime manifest also rejects duplicate physical destinations even when namespaces differ.

## Manifest inspection

`lexicon.furnish.manifestData` is a list of entries with these top-level fields:

<!-- furnish-manifest-entry-fields: authority cleanupStrategy executor filesystemIdentity managedRoot onConflict provenance representation retainedArtifactTarget schemaVersion selfHealStrategy -->

- `schemaVersion`
- `filesystemIdentity`
- `authority`
- `managedRoot`
- `onConflict`
- `representation`
- `retainedArtifactTarget`
- `executor`
- `cleanupStrategy`
- `selfHealStrategy`
- `provenance`

The declaration's `source` record isn't copied into an entry. The selected executor replaces it with `retainedArtifactTarget` and lifecycle strategy fields. `provenance` contains `declaration` and `source`.

`manifestPath` points to a JSON document with `schemaVersion`, `diagnosticContract`, and `entries` when runtime is enabled. The pure compiler leaves it `null`; the NixOS module materializes it with `pkgs.writeText`.

## Compiler call
`compile` has this shape:

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

All fields have the shown defaults. `lexicon.lib.furnish` itself still requires `resolve` and `resolveSystem`. Direct runtime declarations use `furnish.core.offProvider`, which rejects Ownerships-tagged declarations.

The result fields are:

<!-- furnish-result-fields: manifestData manifestDocument manifestJson manifestPath raw -->

| Field | Shape |
| --- | --- |
| `manifestData` | Ordered manifest-entry list |
| `manifestDocument` | `{ schemaVersion; diagnosticContract; entries; }` |
| `manifestJson` | JSON string preserving source artifact context |
| `manifestPath` | `null` in pure compilation |
| `raw` | The caller's value, returned unchanged |

With no declarations, compilation emits an empty manifest and returns `raw` without selecting a provider or compiling executors.

## `files.mkDeclarations`

This integration helper has the exact call shape:

```nix
furnish.files.mkDeclarations {
  filesystemNamespace = namespace;
  principals = [ ... ];
  files = [ ... ];
}
```
Arguments:

| Argument | Required | Meaning |
| --- | --- | --- |
| `filesystemNamespace` | Yes | Copied to every emitted declaration |
| `principals` | Yes | Principal records; only `authority.scope = "user"` produces declarations |
| `files` | No | File entries; defaults to `[ ]` |

Each user principal supplies `authority` and may supply `managedRoot`; the default root is `/home/${authority.identity}`. Each file entry requires `src` and `dest` and may supply:

| File field | Emitted declaration field |
| --- | --- |
| `label` | `label`; default `files[${dest}]` |
| `representation` | `representation`; default `symlink` |
| `onConflict` | Included only when present |
| `provenance` | `provenance.source` |

The helper emits `source = { kind = "path"; value = src; }`. It doesn't copy Ownerships claim keys and doesn't generate system declarations.

## Failure boundaries

Common authoring failures include:

| Failure | When it occurs |
| --- | --- |
| Shape validation | Required field missing or wrong type; invalid authority scope or conflict policy |
| `ownerships-disabled` | A direct runtime declaration contains an Ownerships claim key |
| `outside-managed-root` | Normalized destination isn't strictly below the normalized root |
| `duplicate-filesystem-identity` | Two selected declarations have the same namespace and absolute destination |
| No capable executor | No enabled executor supplies `lifecycle-baseline` plus the representation capability |
| Duplicate executor identity | Registry contains two executors with the same `identity` |
| Artifact validation | Selected executor returns no path-like target or an unknown strategy |

At coordinator runtime, invalid manifest tuples, duplicate physical destinations, unresolvable user accounts, missing roots, symlinked parent components, unowned existing destinations, and missing ledger evidence are refused rather than inferred.

See [runtime and safety](runtime.md) for state-changing behavior and [advanced reference](advanced-reference.md) for executor/provider details.

[Back to Furnish](README.md) · [Usage](usage.md) · [Worked example](worked-example.md)
