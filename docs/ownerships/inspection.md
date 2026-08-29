# Trace and matrix inspection

Trace and matrix are read-only projections of the same resolver machinery. They
are deliberately not alternate implementations of ownership semantics — both
go through `selectPrepared`, the shared selection boundary, so a report cannot
disagree with a real resolve.

## Tracing one context

```nix
trace = ownerships.mkResolveTrace roster units ctx;
```

System scope uses `mkResolveSystemTrace`.

You get `value`, identical to ordinary resolution, plus one selection record
per composed leaf, effective claims and per-axis decisions, rejecting axes,
leaf-check and context-demand results, pre-merge contribution shape, stage
reports, and lazy merge provenance.

### Selection records

A leaf record identifies its safe unit identity, its stable `key`, its
effective claim, each axis's claim and decision, whether it selected, and which
axes rejected it.

A global claim reports decision `global` without ever reading a context entity.

Records are available as a list and as `byKey`. Prefer `byKey` when you are
correlating across stages — the lists are positional, and a stage that filters
one of them shifts the others.

### Pre-merge versus post-merge

`preMergeContribution.offeredPaths` shows what a selected leaf *offered*. It
does not tell you who owns the final value.

For that, use `mergeProvenance`, which is path-aligned and post-merge. The two
answer different questions and it is easy to reach for the wrong one.

### Stage reports

`stageReports` separates the leaf, tree, and survivor views. A failing leaf
phase also exposes lazy `diagnosticText.leaf`, so tests and audit tooling can
read the exact aggregate text without switching to a different checker.

## Strict resolution

```nix
strict = ownerships.mkResolveStrict roster;
```

Ordinary resolution validates claims but only reads the context entities those
claims demand. Strict resolution additionally represents the supplied context
as a claim and validates it against the roster and its registered relations.

The check runs before the resolve body, not from inside the context. That
distinction is load-bearing: a globally owned unit narrows on nothing and never
forces the context, so a check hung off the context thunk would silently skip
exactly the declarations with no other guardrail.

Use strict for external or audit contexts that must themselves be known. Do not
use it to change selection — a successful strict resolve delegates to the same
ordinary resolver.

## Prepared resolvers

```nix
resolveForHost = ownerships.mkResolveSystemPrepared roster units;
```

Translation, composition, and the leaf and tree stages depend only on the
units, so `prepared` runs them once when the units are handed in. What comes
back is context demand, selection, survivor stages, and merge.

Use it to resolve one unit list across many contexts, which is what a fleet
report or a per-host projection does. `applyPrepared` rejoins the two halves on
the leaf `key`, so the association survives any stage that filtered a list.

## Fleet matrix

```nix
matrix = ownerships.mkResolveMatrix roster { inherit units; };
```

System scope uses `mkResolveSystemMatrix`.

User rows come from known host membership. Users with unknown membership do not
invent rows.

The matrix runs compose, leaf-stage classification, tree stages over live
leaves, then context demand, selection, and survivor stages per row. It does
not merge payloads and does not build provenance.

### Fields

**`units`** maps stable snapshot keys such as `leaf-0` to safe identity and
shallow shape. These describe position in this report, not durable source
identity.

**`byContext`** reports, per context, the canonical host and optional user
name, survivor leaf keys, inactive keys with their rejecting axes, and unique
top-level pre-merge paths.

**`dead`** holds leaves proven impossible by leaf diagnostics, with reasons —
impossible same-axis claims and incompatible registered relations.

**`neverSelectedInModeledContexts`** holds valid live leaves that every
generated row rejected, with per-context rejecting axes. A predicate that
happens to be false everywhere belongs here, not in `dead`.

**`indeterminate`** holds user claims that select nowhere in modeled rows but
name users whose host membership is unknown. The report cannot tell dormant
from potentially-active-on-an-unmodeled-host, and says so rather than guessing.

**`coverage.units`** maps each leaf key to the contexts that select it.
`coverage.preMerge.paths` maps top-level offered paths to contexts, preserving
first-occurrence order.

**`hostDiffs`** reports, for each ordered host pair, the left-only and
right-only survivor keys and pre-merge paths. In user scope, a host's ownership
is the union across that host's modeled user rows.

`hostDiffs` and `coverage.units` are the two fields worth reaching for after a
refactor. A structural change that was supposed to preserve behaviour should
produce an identical projection.

### Enriched contexts

Predicates can read more than names, so supply `contextFor`:

```nix
ownerships.mkResolveMatrix roster {
  inherit units;
  contextFor =
    { hostName, userName }:
    {
      host = {
        id = hostName;
        gpu = roster.dimensions.gpu.byHost.${hostName};
      };
      user.name = userName;
    };
}
```

The callback must still supply the entity fields registered descriptors
require.

## Safety boundary

Trace may expose opaque effective claims and lazy provenance, because it is
tied to one real resolution the caller already asked for.

Matrix is stricter. Raw payloads never cross its report boundary. Safe reports
may contain author-supplied labels and sources, shallow attrset keys,
derivation names when safely available, canonical roster identities, claim
data, stage and selection decisions, and path names.

They must never serialize packages, secret-backed values, function bodies, or
arbitrary payload attrsets.
