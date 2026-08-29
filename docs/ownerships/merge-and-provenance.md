# Merge, profiles, locks, and provenance

Ownerships merges selected plain values by shape. One recursive tracked merge
serves ordinary values, diagnostics, profiles, locks, and provenance.

## Default rules

The built-in `strict-ordered` behaviour:

- attrsets deep-merge by key;
- lists concatenate in source order;
- equal scalars keep the first value;
- differing scalars conflict;
- equal derivations compare by `outPath`;
- functions are always unequal.

Lists are terminal. Their strategy owns the list as a whole, so provenance
never invents per-element ownership.

## How a path is decided

Before anything is merged, the treatment at a path is resolved into a tagged
decision record — `deep`, `take-right`, `list`, `scalar`, or `bad-treatment`.
The arms are a lazy table keyed by that tag.

This matters for debugging. The choice at a path is a value you can look at,
rather than a position partway down a chain of conditionals that only exists
while the merge is running.

## Tracked entries

```nix
{
  value = { services.example.enable = true; };
  contributor = {
    identity = "unit 'example'";
    owners = { ...effective claims... };
    mergeProfile = "strict-ordered";
  };
}
```

The result is:

```nix
{
  value = { ...merged value... };
  provenance = {
    path = "";
    contributors = [ ... ];
    children.services.children.example = ...;
  };
}
```

Ordinary resolution projects `.value`. Provenance is built lazily alongside it.

## Built-in list strategies

| Name | Behaviour |
| --- | --- |
| `ordered-concat` | Append right to left in source order. |
| `dedup-union` | Append, keeping the first occurrence of each equal item. |
| `take-right` | Replace the left list with the right list. |

Unprofiled low-level callers can choose per path with `listStrategyFor`.

## Built-in profiles

```nix
strict-ordered = {
  listStrategy = "ordered-concat";
  scalarPolicy = strictScalar;
  attrsetTreatment = "deep";
};

last-wins = {
  listStrategy = "take-right";
  scalarPolicy = takeRightScalar;
  attrsetTreatment = "take-right";
};
```

Use `last-wins` sparingly. It suppresses disagreement on purpose, which means
it also suppresses the error that would have told you two units are fighting.

## Profile selection

At a merge path:

1. a non-null `profileForPath path` wins;
1. otherwise a unanimous explicit contributor profile wins;
1. otherwise `strict-ordered` applies where disagreement rules allow.

Different explicit profiles conflict for scalars. Mixing explicit and default
profiles conflicts for list or overlapping attrset decisions that need one
coherent treatment. A path profile overrides unit disagreement at that path.

A parent profile does not inherit into child contributors.

## Validation and laziness

Profiled surface constructors validate authored profile names on every unit,
including inactive ones — a typo should not wait for the machine that happens
to select it.

The merge layer validates an activated profile record before use. The profile
name must be a string, its value an attrset, `listStrategy` a string naming a
registered function, `scalarPolicy` a function, and `attrsetTreatment` either
`deep` or `take-right`.

Unused profile registrations stay lazy, so an optional or generated registry
does not force every entry during an unrelated resolve.

## Custom profiles

```nix
let
  profiles = ownershipsMerge.builtinProfiles // {
    union-lists = {
      listStrategy = "dedup-union";
      scalarPolicy = ownershipsMerge.strictScalar;
      attrsetTreatment = "deep";
    };
  };

  resolveProfiled = ownerships.mkResolveProfiled { inherit profiles; } roster;
in
resolveProfiled [
  {
    mergeProfile = "union-lists";
    packages = [ "a" "b" ];
  }
  {
    mergeProfile = "union-lists";
    packages = [ "b" "c" ];
  }
] ctx
```

The facade exposes profiled resolver constructors, not the merge module
itself. Custom merge work is an advanced library concern.

## Single-writer locks

```nix
lockFor = path:
  if path == "services.example" || lib.hasPrefix "services.example." path then
    contributor: contributor.identity == "unit 'owner'"
  else
    null;
```

Authorization runs before shape dispatch and before scalar equality, so a
foreign contributor violates a lock even when it writes an identical value.
That is the point — the lock is about who may write, not about what the value
turns out to be.

Locks are path-local. A subtree policy must match descendants explicitly.

Without `lockFor`, a single-contributor attrset can be adopted whole without
walking its descendants. Opting into locks requires that walk, so nested writes
cannot slip past authorization.

## Reading provenance

A provenance node answers which selected leaves reached that value path. It
does not claim one contributor exclusively owns the resulting semantic option.

For lists, contributors own the merged list node. For attrsets, child
provenance narrows to the contributors that supplied each branch. For terminal
conflicts, diagnostics use safe contributor identity and never render the
differing values.

Use trace merge provenance for post-merge attribution.
`preMergeContribution.offeredPaths` answers a different and narrower question —
which top-level paths a selected leaf offered before merge ran.
