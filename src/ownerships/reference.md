# Ownerships API

`inputs.lexicon.lib.ownerships { descriptors ? null, relations ? null }` returns
the API below. Null selects the built-in host, user and predicate descriptors
and the host-user membership relation.

## Roster

| Function | Signature | Result |
| --- | --- | --- |
| `define.host` | `name`, optionally applied to `{ system ? "standalone", dimensions ? {}, aliases ? [ name ] }` | Host declaration; canonical ID `"${system}/${name}"` |
| `define.user` | `name: { hosts ? null, id ? name, aliases ? [ name ] }` | User declaration |
| `toRoster` | `declarations` | Roster projected from the declaration list |
| `mkRoster` | `descriptors` | `{ define, toRoster }` for that descriptor set |

A host declaration can be used as `define.host "name"` without applying the
optional argument set. `define.user` requires its argument set.

`hosts = null` on a user means unknown membership; `hosts = []` means known
membership on no host. Repeated declarations union membership. User host
references accept canonical IDs or unambiguous aliases. Unknown and ambiguous
host references fail.

| Roster field | Meaning |
| --- | --- |
| `hosts`, `users` | Lists of canonical IDs |
| `aliases.host`, `aliases.user` | Alias to list of matching canonical IDs |
| `display.host`, `display.user` | Canonical ID to display name |
| `membership` | Canonical host ID to list of user IDs |
| `usersWithUnknownMembership` | User IDs declared with null membership |
| `dimensions` | Dimension name to `{ members, byHost }` |

## Units and claims

| Field | Type / meaning |
| --- | --- |
| `hosts` | List of host IDs or aliases to include |
| `exceptHosts` | List of host IDs or aliases to exclude |
| `users` | List of user IDs or aliases to include |
| `exceptUsers` | List of user IDs or aliases to exclude |
| `when` | `ctx: bool` predicate |
| `children` | List of nested units; default `[]` |
| `value` | Configuration attribute set, instead of inline configuration |
| `label`, `source` | Optional plain strings identifying the unit in diagnostics |
| `mergeProfile` | Profile name for profiled resolution |
| Other fields | Inline configuration payload |

Claims are intersected with ancestor claims. An unclaimed unit is globally
owned. `hosts` and `exceptHosts` cannot coexist on one unit; the same applies
to `users` and `exceptUsers`. Empty includes own nothing. Unknown names,
ambiguous aliases and impossible ownership claims are errors in ordinary
resolution. Known host-user membership rejects incompatible claims.

`value` cannot coexist with inline configuration keys. It permits configuration
paths named `users`, `hosts` or other reserved keys. Metadata is stripped before
merge. A metadata-only unit without configuration or children is invalid.

Contexts use `host` and, at user scope, `user` attribute sets. Host identity is
`host.id`, or `"${host.system or "standalone"}/${host.name}"`; user identity is
`user.id` or `user.name`. Predicates receive the normalized build context.
System scope binds no user and rejects `users`/`exceptUsers` anywhere in the tree.

## Resolution

`mkResolvers roster` returns the following functions sharing one compiled roster.

| Attribute | Signature | Result |
| --- | --- | --- |
| `resolve`, `resolveSystem` | `units: ctx: config` | Merged selected configuration |
| `trace`, `systemTrace` | `units: ctx: report` | Value plus selection and merge observations |
| `prepared`, `systemPrepared` | `units: ctx: config` | Same value API; prepares context-independent work once when units are applied |
| `strict`, `systemStrict` | `units: ctx: config` | Also validates context against roster even for global units |
| `matrix`, `systemMatrix` | `{ units, contextFor ? defaultContext }` | Read-only coverage report over modeled roster contexts |
| `profiled`, `systemProfiled` | `profileArgs: units: ctx: config` | Configurable merge policies |
| `resolverFor` | `{ scope ? "user", projection ? "value", strict ? false, profileArgs ? null }` | Resolver bound to this roster |

Top-level `resolverFor` accepts the same fields plus required `roster` and
optional `base` (compiled engine arguments). `scope` is `"user"` or `"system"`.
`projection` is `"value"`, `"trace"`, `"prepared"` or `"matrix"`.

Standalone aliases take `roster` first, then the corresponding arguments:
`mkResolve`, `mkResolveSystem`, `mkResolveTrace`, `mkResolveSystemTrace`,
`mkResolvePrepared`, `mkResolveSystemPrepared`, `mkResolveStrict`,
`mkResolveSystemStrict`, `mkResolveMatrix`, `mkResolveSystemMatrix`.
`mkResolveProfiled` and `mkResolveSystemProfiled` take `profileArgs` before `roster`.

Default merge recursively combines attribute sets and concatenates lists in
unit order. Equal terminal values are accepted; differing terminal values
conflict. Functions cannot be compared and conflict when co-owned. Derivations
are terminal values compared by `outPath`. Ownership merge does not implement
NixOS module-priority semantics.

Trace fields are `value`, `mergeProvenance`, `trace`, `stageReports`,
`diagnosticText.leaf`. Matrix fields are `units`, `byContext`, `coverage`,
`hostDiffs`, `display`, `dead`, `indeterminate`,
`neverSelectedInModeledContexts`. Matrix coverage records offered top-level
paths before merge, not final configuration values. Impossible leaves appear in
`dead`. Unknown membership can make coverage indeterminate.

For user matrices, `contextFor` receives `{ hostName, userName }`; for system
matrices it receives `{ hostName }`. `hostName` is the canonical ID. Defaults
bind `host.id` and optional `user.name`.

## Merge policy arguments

| `profileArgs` field | Default / contract |
| --- | --- |
| `strategies` | Built-ins `ordered-concat`, `dedup-union`, `take-right`; each `leftList: rightList: list` |
| `listStrategyFor` | `path: "ordered-concat"` |
| `conflictPolicy` | Strict scalar comparison; callback `path: leftNode: rightNode: value` |
| `lockFor` | `path: null`; otherwise returns `contributor: bool`, rejecting foreign writes |
| `profiles` | Built-ins `strict-ordered` and `last-wins` |
| `profileForPath` | `path: null`; otherwise returns a profile name overriding unit choices |

Paths are dot-separated strings; root is `""`. Scalar nodes contain `value`
and `contributors`. Contributors contain diagnostic `identity`, effective
`owners` claims and optional `mergeProfile`. Each profile requires `listStrategy` (strategy name),
`scalarPolicy` (scalar callback), `attrsetTreatment` (`"deep"` or `"take-right"`).
`strict-ordered` uses ordered list concatenation, strict scalars and deep sets.
`last-wins` takes the right value for lists, scalars and sets.
Conflicting explicit unit profiles require a path-level ruling at a shared
terminal or list path. Mixing profiled and unprofiled contributions rejects
shared lists and uses strict scalar comparison; attribute sets merge deeply.

## Other functions

| Attribute | Signature / behavior |
| --- | --- |
| `claimKeys` | Ordered list `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when` for default descriptors |
| `projectClaims` | `scope: claims: claims` with axes forbidden in that scope removed |
| `translate` | `unit: claimTree` with claims separated from payload |
| `importUnits` | `{ dir, args ? {} }`; recursively imports regular `.nix` files in relative-name order |
| `importUnitSets` | `{ dir, args ? {} }`; returns `{ home, system }` lists from those subdirectories |

Imported files return a unit or list of units; functions receive `args`.
Discovery rejects symlinks and special entries. Mixed unit trees require at
least one `home` or `system` directory and reject loose `.nix` files and unknown
subdirectories.

## Custom descriptors

Supplying `descriptors` replaces the default descriptor list. Each descriptor
requires `name`, `authorKeys`, `roster` (attribute set or null), `allowedScopes`
(string list), and callbacks `parse`, `axisFor`, `ctxClaim`, `ctxLabel`,
`leafStages`, `scopeError`. Each author key requires `name`, integer `order`,
`valid = value: bool`, and `shapeError = value: string`. Descriptor and author
key names must be unique. Non-null roster projections require `define` and
`project`; `mkRoster` exposes those definitions and runs projections in order.

Supplying `relations` replaces the default relation list. Each relation requires
unique `name`, registered `leftAxis` and `rightAxis`, and callbacks `unknownFor`,
`compatibleFor`, `reason`. Custom descriptors and relations are engine-level
contracts; the standard consumer claim vocabulary is the default set above.
