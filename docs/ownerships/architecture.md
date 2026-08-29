# Ownerships architecture

Ownerships is descriptor-driven at the author and roster boundaries, and
axis-agnostic in the engine. The engine never branches on `host`, `user`, or
`when`.

## Pipeline

```text
optional file discovery
→ translate
→ compose
→ leaf stages
→ tree stages
→ context demand
→ selection
→ survivor stages
→ contributor projection
→ merge
```

Each diagnostic phase aggregates every diagnostic it can find before throwing.
A failed phase prevents later phases from evaluating.

## Optional unit discovery

`import-units.nix` sits in front of the pipeline as an input convenience. It
adds no selection stage and infers no ownership from file paths.

`importUnits` discovers `.nix` files recursively, sorts them by relative path,
imports them, calls function files with `args`, and flattens the results.
`importUnitSets` classifies a mixed tree through explicit `system` and `home`
directories and rejects anything it cannot classify. Both validate only the
outer unit shape; payload fields stay lazy.

## Translation

`surface.nix` converts self-labeling units into engine grammar:

```nix
{
  hosts = [ "khion" ];
  label = "example";
  services.example.enable = true;
}
```

becomes, conceptually:

```nix
{
  claim.host = include [ "khion" ];
  label = "example";
  value.services.example.enable = true;
}
```

The surface validates reserved-key shape, scope restrictions, `value`
exclusivity, and profile names. It holds no claim algebra and no selection
logic.

## The resolver carrier

`surface.nix` exposes one resolver body, `resolverFor`, parameterized on scope,
projection, strictness, and merge profile. The named `mkResolve*` doors are
generated from a table over it. [Doors](doors.md) covers the surface itself.

The structural consequence is that a door is a row of data rather than a
function body, so behaviour cannot diverge between two doors that should agree.

## Descriptor compilation

`axes.compileDescriptors` validates a descriptor set once and projects ordered
descriptors, ordered author-key metadata, public claim keys, and the
descriptors that have roster projection. Surface validation, registry
construction, and roster construction reuse that compiled metadata.

A compiled descriptor set can be handed to `resolverFor` as `base`, which is
how `mkResolvers` builds a dozen doors for one roster while compiling its
descriptors once.

A descriptor owns its axis name and implementation, author keys and their
ordering, shape validation and parsing, allowed scopes and scope-specific
errors, context claim and label projection, an optional declaration constructor
and roster projector, and optional leaf stages.

The production descriptors are `host`, `user`, and `when`.

## Compose

`engine.compose` walks the translated tree, narrowing the parent's effective
claim with each node's own claim on every registered axis.

Every config-bearing node produces one leaf carrying its effective claim, an
opaque payload, optional label and source, an optional merge profile, and a
stable `key` derived from its path in the tree.

Nodes without payload may still scope their descendants. Identity and merge
profile do not inherit.

## Stages

```nix
{
  view = "leaf" | "tree" | "survivors";
  run = ...;
}
```

Unknown views or missing callbacks throw.

**Leaf stages** run one rule over one composed leaf. Production order is
ambiguous-alias validation, per-axis satisfiability, registered cross-axis
relations, then descriptor-contributed stages. Diagnostics flatten in stage
order, then leaf order.

**Tree stages** receive `{ registry; leaves; }` after leaf validation and
before context demand. They express whole-declaration invariants independent of
the current build.

**Survivor stages** receive `{ registry; ctx; survivors; }` after selection.
They express current-build coverage, such as requiring exactly one selected
provider.

## Context demand and selection

A set axis with a non-global claim requires the entity named by its `ctxKey`. A
global claim short-circuits and never reads the context entity.

This is why an untagged unit resolves without host or user values. Missing
context is an error only when an authored claim actually narrows that axis.

It is also why strict validation cannot be attached to the context value. A
globally owned unit never demands the context, so a check that only fires when
the context is forced would never run for it. Strict doors validate before the
resolve body instead.

`selectPrepared` is the shared boundary used by both ordinary resolution and
matrix projection. It performs context-demand validation, per-axis selection,
survivor stages, and the selection, context, and survivor traces. Sharing this
boundary is what keeps matrix behaviour from drifting away from real
resolution.

## Stable leaf keys

Selection, context, and survivor results are exposed both as lists and as
`byKey` and `ctxByKey` maps keyed by the leaf's `key`.

The lists are positional and any stage that filters one of them shifts the
others. Rejoining by key is order-independent, which is how `applyPrepared`
re-associates a prepared half with a fresh context.

## Contributor projection and merge

Selected leaves become tracked entries. Each contributor carries a safe
identity, opaque effective owners, and an optional merge profile.

The merge layer interprets value shape and merge policy, never ownership
semantics. Ordinary resolve projects only the merged value; trace callers can
inspect the lazy provenance sibling.

Within merge, the treatment at a path is decided before it is applied. The
decision is a tagged record and the arms are a lazy table keyed by that tag, so
what will happen at a path is a value you can inspect without running the
merge.

## Projections

- **Plain resolve** returns only the merged value.
- **Trace** runs the same pipeline and exposes decisions and provenance.
- **Prepared** splits the unit-only half from the context-only half.
- **Matrix** runs compose, leaf stages, tree stages, context demand, selection,
  and survivor stages, but deliberately does not merge payloads.
- **Strict** additionally validates the supplied context against the roster.
- **Profiled** activates merge-profile semantics and validation.

## Laziness boundaries

Ownerships must preserve all of these:

- imported files force only the unit shell needed for normalization;
- inactive payloads are never merged;
- safe identity does not serialize arbitrary payloads;
- ordinary resolve does not force trace details;
- merge provenance stays lazy unless inspected or required by locks or
  profiles;
- unused merge-profile registrations stay lazy;
- matrix reports expose only identity, shallow shape, claims, decisions, and
  path names.

The counterweight is that anything which must *always* happen cannot be hung
off a value a caller might never force. Validation that has to run belongs
before the body that returns the result.

## Extending the pipeline

Add a descriptor for new axis vocabulary. Add relation data for cross-axis
compatibility. Add a stage only when an invariant belongs at an existing
pipeline boundary. Add a projection by adding a row to the projections table.

Do not teach the engine a new axis name. Do not implement alternate selection
in matrix or trace. Do not add a merged-output stage until a real invariant
requires that boundary and its safe data contract is defined.
