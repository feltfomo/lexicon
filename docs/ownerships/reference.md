# Ownerships reference

## Unit grammar

```nix
{
  # optional claims
  hosts = [ ... ];
  exceptHosts = [ ... ];
  users = [ ... ];
  exceptUsers = [ ... ];
  when = ctx: true;

  # optional metadata
  label = "...";
  source = "...";
  mergeProfile = "...";

  # payload, choose one form
  services.example.enable = true;
  # or: value = { ... };

  # optional descendants
  children = [ ... ];
}
```

`label`, `source`, and `mergeProfile` do not inherit. Claims do inherit,
through narrowing.

## Public facade

All of these are exported from `src/ownerships/default.nix`.

### The carrier

| Function | Result |
| --- | --- |
| `resolverFor { roster, base ? ..., scope ? "user", projection ? "value", strict ? false, profileArgs ? null }` | One resolver built from the four axes. |
| `mkResolvers roster` | Every door for that roster, over one compiled descriptor set. |

Prefer `mkResolvers` whenever a call site needs more than one projection. It
compiles the roster's descriptors once and shares them:

```nix
let doors = ownerships.mkResolvers roster;
in {
  config = doors.resolve units ctx;
  audit = doors.matrix { inherit units; };
}
```

Its keys are `resolve`, `resolveSystem`, `trace`, `systemTrace`, `prepared`,
`systemPrepared`, `matrix`, `systemMatrix`, `strict`, `systemStrict`,
`profiled`, `systemProfiled`, and `resolverFor` rebound to the shared base.

### Named doors

Generated from a table over `resolverFor`, so a name cannot drift from its
behaviour. See [doors](doors.md).

| Function | Result |
| --- | --- |
| `mkResolve roster units ctx` | User-scope merged value. |
| `mkResolveSystem roster units ctx` | System-scope merged value. |
| `mkResolveTrace roster units ctx` | User value, decisions, stages, and provenance. |
| `mkResolveSystemTrace roster units ctx` | System trace. |
| `mkResolvePrepared roster units` | User resolver with the ctx-free half already done. |
| `mkResolveSystemPrepared roster units` | System prepared resolver. |
| `mkResolveMatrix roster { units; contextFor ? ...; }` | User fleet projection. |
| `mkResolveSystemMatrix roster { units; contextFor ? ...; }` | System fleet projection. |
| `mkResolveStrict roster units ctx` | User resolve after roster-validating the context. |
| `mkResolveSystemStrict roster units ctx` | System strict resolve. |
| `mkResolveProfiled args roster units ctx` | User resolve with merge profiles enabled. |
| `mkResolveSystemProfiled args roster units ctx` | System profiled resolve. |

### Rosters and units

| Function | Result |
| --- | --- |
| `translate unit` | Translate author syntax to engine grammar. |
| `claimKeys` | Ordered public claim-key list. |
| `define.<axis>` | Standalone declaration constructor. |
| `toRoster declarations` | Project the default descriptor roster. |
| `mkRoster descriptors` | Construct a custom descriptor-driven roster facade. |
| `importUnits { dir; args ? { }; }` | Recursively import one unit collection. |
| `importUnitSets { dir; args ? { }; }` | Import optional `system` and `home` collections. |

The roster argument is curried:

```nix
resolve = ownerships.mkResolve roster;
value = resolve units ctx;
```

## Prepared resolvers

`prepared` splits the work in two. Translation, composition, leaf stages, and
tree stages depend only on the units, so they run once when the units are
handed in. The returned function is context demand, selection, survivor stages,
and merge:

```nix
let resolveForHost = ownerships.mkResolveSystemPrepared roster units;
in lib.genAttrs hostNames (name: resolveForHost { host = hostFor name; })
```

Use it when one unit list is resolved against many contexts. For a single
context it is the same work in a different order.

## Unit import helpers

### `importUnits`

```nix
units = ownerships.importUnits {
  dir = ./units;
  args = { inherit pkgs; };
};
```

Recursively visits directories, imports regular `.nix` files, ignores other
regular files, and rejects symlinks and unknown entry types rather than
following or silently skipping them. Files are sorted by relative path before
import, which is what makes ordered list concatenation deterministic. Function
files receive `args`. Each file returns one unit attrset or a list of them, and
all results flatten into one list. Only the outer unit shell is forced.

It assigns no scope. Pass the result to the resolver you want.

### `importUnitSets`

```nix
unitSets = ownerships.importUnitSets {
  dir = ./units;
  args = { inherit pkgs; };
};
```

The root may contain `system`, `home`, or both. The result always has both
keys; a missing collection is an empty list. At that root, loose `.nix` files
and unknown directories are errors — a plain attrset does not reveal which
module system owns it, so the boundary has to be explicit. Non-Nix regular
files at the root are ignored.

## Claim keys

In stable validation order:

```nix
[
  "hosts"
  "users"
  "exceptHosts"
  "exceptUsers"
  "when"
]
```

Custom descriptor surfaces may append keys without changing the production
default.

## Scope rules

| Axis | User scope | System scope | Context key |
| --- | --- | --- | --- |
| host | yes | yes | `host` |
| user | yes | no | `user` |
| when | yes | yes | none |

System scope recursively rejects forbidden keys before selection, and reports
**every** offending key in the tree rather than the first one found.

## Built-in merge values

List strategies: `ordered-concat`, `dedup-union`, `take-right`.

Profiles: `strict-ordered`, `last-wins`.

Attrset treatments: `deep`, `take-right`.

Conflict policies are functions receiving `path` and the left and right tracked
nodes.

## Stage API

```nix
{ view = "leaf";      run = registry: leaf: diagnostics; }
{ view = "tree";      run = { registry, leaves }: diagnostics; }
{ view = "survivors"; run = { registry, ctx, survivors }: diagnostics; }
```

Diagnostics are domain records the engine converts to Krisis diagnostics.
Common fields are `kind`, `unit`, `label`, `source`, `axis` or `axes`,
`claims`, and `reason`.

## Leaf keys

Every composed leaf carries a `key` derived from its position in the tree —
`"0"`, `"0/1"`, `"0/1/2"`. Selection, context, and survivor stages expose
`byKey` and `ctxByKey` alongside their lists, and prepared resolvers rejoin on
the key rather than zipping by index.

A key describes position in one report. It is not durable source identity;
reordering the unit list changes it.

## Error classes

### Author shape

Unit is not an attrset; malformed claim value; both polarities on one axis;
malformed children, value, label, source, or profile; `value` mixed with inline
payload; forbidden scope key.

### Impossible declaration

Unknown member; disjoint nested claim; empty include; ambiguous alias; no
compatible pair for a registered relation.

### Context

A narrowed axis has a non-null `ctxKey` but the build context supplies no
entity. Strict doors additionally reject unknown or incompatible supplied
contexts, even when every authored claim is global.

### Merge

Differing strict scalar values; foreign write beneath a lock; unknown or
malformed strategy; unknown or malformed activated profile; incompatible
contributor profiles.

### Stage

Unknown view, malformed callback, or a stage-produced structured diagnostic.

### Unit import

Non-attrset `args`; a file returning neither a unit attrset nor a list of them;
unsafe filesystem entry type; loose root `.nix` file in a mixed tree; unknown
top-level directory in a mixed tree.

## Glossary

- **unit** — author attrset containing payload and optional ownership metadata
- **claim** — restriction along registered axes
- **axis** — implementation of one ownership dimension
- **descriptor** — author, context, scope, axis, and roster metadata for an axis
- **top/global** — the identity claim that selects everyone
- **narrow/meet** — combine parent and child claims without widening
- **leaf** — config-bearing composed node with an effective claim
- **stage** — validation callback at a pipeline boundary
- **relation** — compatibility rule between two axes
- **roster** — canonical members, aliases, membership, dimensions, display data
- **context** — concrete entities for one resolve
- **survivor** — selected leaf after context matching
- **contributor** — survivor identity and effective owners carried to merge
- **provenance** — path-aligned contributor tree
- **matrix** — structural selection report across modeled contexts

## Lower-level seams

`resolve.nix` exports `resolveWith`, `engineArgsFor`, and `validateCtxWith`.
`engine.nix`, `axes.nix`, `merge.nix`, and `matrix.nix` export further focused
seams for tests and subsystem composition. `surface.nix` additionally exports
`projectClaims`, which narrows a claim into a scope so an extension can build
an enclosing unit without tripping the scope guard.

These are reachable by importing the file, not through the facade.
`default.nix` deliberately does not re-export them and the furnish suite
asserts their absence, so a consumer cannot reach the engine by accident.

They are not ordinary aspect APIs. Preserve facade behaviour when changing
them, and add parity and forcing tests around any new seam.
