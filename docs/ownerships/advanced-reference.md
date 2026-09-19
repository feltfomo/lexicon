# Advanced Ownerships reference

Use this page for merge policy configuration or tooling built on the exported support functions. Ordinary declarations and resolvers are in the [reference](reference.md). Nothing here is needed for the first lesson.

## Merge policies

`ownerships.mkResolveProfiled profileArgs roster units context` and `ownerships.mkResolveSystemProfiled profileArgs roster units context` return merged data. The second uses system-scope claim restrictions. `profileArgs = { }` enables the built-in profiles; `resolverFor` accepts the same record under `profileArgs`.

| Field | Type and default |
| --- | --- |
| `profiles` | Profile-name → profile record. Defaults to `"strict-ordered"` and `"last-wins"`. A supplied map replaces the defaults. `null` disables the profiled merge and its other options. |
| `profileForPath` | Path string → profile name or `null`; defaults to always `null`. A non-null answer takes priority over unit profiles at that merge path. |
| `strategies` | Name → `(leftList: rightList: resultList)`. Defaults to `"ordered-concat"`, `"dedup-union"`, and `"take-right"`. A supplied map replaces the default strategies. |
| `lockFor` | Path string → contributor predicate or `null`; defaults to no lock. Every contributor must pass a supplied predicate. |
| `listStrategyFor` | Path → strategy name; underlying default is `"ordered-concat"`. Accepted by the merge options, but enabled profiles choose their own `listStrategy` instead. |
| `conflictPolicy` | `path: leftNode: rightNode: value`; underlying default is strict equality/conflict. Enabled profiles use their own `scalarPolicy` instead. |

Put custom behavior in `profiles`, rather than relying on the last two underlying options through a profiled resolver. An unknown option is a Nix function-argument error.

Every profile requires:

| Field | Shape |
| --- | --- |
| `listStrategy` | Name of a function in `strategies`. |
| `scalarPolicy` | `path: leftNode: rightNode: mergedValue`. Nodes contain `value` and `contributors`; they can also carry provenance. |
| `attrsetTreatment` | `"deep"` or `"take-right"`. |

`"strict-ordered"` recursively merges ordinary attribute sets, concatenates lists, and uses the [default terminal rules](reference.md#merge-defaults). `"last-wins"` takes the right list or terminal. At an attribute-set path with an overlapping key, it takes the entire right attribute set; disjoint attribute sets still combine.

Path strings use `""` for the root and dot-joined field names below it. They aren't escaped structural paths, so avoid literal dots in data keys when writing path policies. `profileForPath` chooses a policy at a collision, not a transformation to run over every value in advance.

The [merge example](../../examples/ownerships-merge/values.nix) is a complete policy configuration. Its `replaced`, `wholeEditor`, and `deduplicated` results show a leaf replacement, subtree replacement, and custom list profile.

Without a path override, contributors must agree on an explicit unit profile. Different profiles on disjoint fields can still deep-merge. On a colliding list, mixed explicit/unprofiled contributions or different explicit profiles fail. Different explicit scalar profiles also fail; mixing one explicit and one unprofiled scalar falls back to strict comparison. One `mergeProfile = "last-wins"` declaration can't unilaterally override another contributor.

A parent's profile isn't inherited by children. Enabled profiling validates named unit profiles even on inactive units. Unknown names or malformed profiles fail; a custom profile map must retain `"strict-ordered"` if any collision will use the fallback. Profile records require all three fields above, even if your example only reaches a list collision.

`lockFor path` returns either `null` or `contributor: bool`. Contributors contain `identity`, `owners` (effective claims), and optional `mergeProfile`. Locks are checked before accepting writes, including writes to otherwise uncontested descendants. A subtree policy must match the subtree's paths, not just its root. Locks express merge policy using supplied identities; they aren't an operating-system security mechanism.

## Support functions

### Claim keys and projection

`claimKeys` is a list of reserved ownership author keys in validation order. The default is `[ "hosts" "users" "exceptHosts" "exceptUsers" "when" ]`. It excludes structural and metadata fields such as `children`, `value`, `label`, `source`, and `mergeProfile`. Custom descriptors change this list.

`projectClaims scope claims` takes a scope string and an attribute set. It removes author keys belonging to axes unavailable in that scope and returns the remaining attributes. With the library bound as in [getting started](getting-started.md), this support snippet keeps the host claim:

```nix
ownerships.projectClaims "system" {
  hosts = [ "laptop" ];
  users = [ "alice" ];
}
```

Result: `{ hosts = [ "laptop" ]; }`. The public factory exports `projectClaims`. It removes unavailable claim keys at this one level and leaves unrelated attributes unchanged, so pass only the claim fields you intend to project.

### Translation

`translate unit` returns a translated tree with `claim`, optional `value`, optional translated `children`, and any supplied `label`, `source`, and `mergeProfile`. Default set claims have `{ tag = "include"; set = names; }` or `{ tag = "exclude"; set = names; }`; `when` is a function. Missing claims aren't filled into this tree.

`translate` checks author shape, reserved-field use, polarity, and metadata-only terminals. The result preserves each node's own authored claims; a child's claims haven't yet been intersected with its parent's. Use a resolver to check the tree against a roster and obtain data for a context. Profile-name validation is part of profiled resolution, not this translation.

### Roster construction

`mkRoster descriptors` takes a complete list of descriptors and returns `{ define; toRoster; }`. `define` maps each descriptor with a roster projection to its `roster.define` function; `toRoster declarations` calls those projections in descriptor order and combines their returned fields. Descriptors with `roster = null` don't add declarations or roster fields.

This constructs a roster vocabulary, not a differently configured resolver. Use the same descriptors for the factory that consumes that roster.

### Resolver base override

`resolverFor` accepts `base = { registry; stages; }` in place of its roster-derived base. `registry` maps axis names to the axis records described below. `stages` is a list of `{ view; run; }` registrations, with optional metadata such as `name`.

- `view = "leaf"`: `run registry leaf` returns diagnostics for one configuration-bearing record.
- `view = "tree"`: `run { registry; leaves; }` returns diagnostics for the collection.
- `view = "survivors"`: `run { registry; ctx; survivors; }` returns diagnostics after selection.

Each callback returns a list, with `[]` meaning no errors. Diagnostic records use `kind`, `reason`, `unit` (payload), optional `label`/`source`, and `axis` or `axes` plus `claims` when relevant. Leaves have `key`, `claim`, `value`, and optional unit metadata. Unknown views or non-function callbacks fail.

The override replaces the built-in checks. Keep the registry consistent with the factory's descriptors and supply all checks your tooling requires. This is an expert, version-sensitive record interface, not a shortcut for suppressing an invalid configuration. `mkResolvers roster` binds its own base, so its bundled `resolverFor` doesn't offer this override.

## Custom descriptors and relations

A factory's `descriptors` and `relations` replace its defaults. If you omit the default host or user descriptor, also replace the default host/user relation. The helper constructors in `src/ownerships/axes.nix` aren't exports of the public factory.

A descriptor is an attribute set with all of these required fields:

| Field | Contract |
| --- | --- |
| `name` | Unique string naming the axis. |
| `authorKeys` | List of `{ name; order; valid; shapeError; }`. Name is a string; order is an integer, unique across all author keys; `valid value` returns Boolean; `shapeError value` returns an error string. |
| `allowedScopes` | List of scope strings where its author keys may be used. |
| `roster` | `null` or a projection record. `define` constructs that axis's declarations; `project { declarations; roster; }` returns fields to combine with the accumulated roster. Projection order matters when one reads earlier fields. |
| `parse` | `unit: claimAttrs`, usually empty when no author key is present, otherwise containing this axis's claim. |
| `axisFor` | `roster: axis`, with the axis contract below. |
| `ctxClaim` | `context: claimAttrs` used to validate a supplied identity in strict resolution. |
| `ctxLabel` | `context: string-or-null` for context diagnostics. |
| `leafStages` | `roster: list-of-stage-registrations` for extra checks. |
| `scopeError` | `scope: authorKey: value: errorString`. |

The resolver reads these fields from an axis returned by `axisFor`:

| Field | Contract |
| --- | --- |
| `top` | The global claim value. |
| `narrow` | `parentClaim: ownClaim: effectiveClaim`. |
| `isTop` | Claim → Boolean. |
| `satisfiable` | Claim → Boolean. |
| `ctxKey` | Context field name string, or `null` for an axis that doesn't demand an entity. |
| `ambiguous` | Claim → list of ambiguous alias strings; return `[ ]` for an axis without aliases. |
| `observe` | Claim → record with `satisfiable` and `select = context: { selected = bool; ...; }`. Other fields become trace details. Set-like axes participating in relations also supply `materializedMembers`. |

A relation registration requires `name`, `leftAxis`, `rightAxis`, `unknownFor`, `compatibleFor`, and `reason`. The names are strings, and both axes must exist. `unknownFor roster` returns `{ left = [ ... ]; right = [ ... ]; }`; `compatibleFor roster leftMember rightMember` returns Boolean; `reason leftMembers rightMembers` returns an error string.

The membership check skips a relation when either side is global. Empty effective sides are handled by axis satisfiability. Otherwise, an unknown member can keep the relation possible; with known members, at least one compatible pair must exist. Choose set-like axes that expose `materializedMembers` for this interface.

Malformed descriptor/author-key records, duplicate axis names, duplicate author-key names or orders, malformed relations, duplicate relation names, and unknown relation axes fail validation. Callback return contracts are still the descriptor author's responsibility; registration doesn't prove their behavior.

[Descriptor tests](../../tests/ownerships/descriptors.nix) exercise an additional axis and relation. [axes.nix](../../src/ownerships/axes.nix), [roster.nix](../../src/ownerships/roster.nix), and [resolve.nix](../../src/ownerships/resolve.nix) define the current record interfaces. Treat those support shapes as version-sensitive when maintaining extensions.

[Back to the public reference](reference.md) · [Inspection outputs](inspection.md#report-fields)
