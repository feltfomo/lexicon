# Inspect a selection

Start here when a setting is missing or you need to check where a unit applies. The existing [preferences example](../../examples/ownerships/preferences.nix) already exposes the reports used below.

## Why did this unit apply?

Run from the repository root:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix preferences.inspection
```

<!-- value: preferences.inspection -->
```json
[
  {"identity":"unit 'common tools'","rejectedBy":[],"selected":true},
  {"identity":"unit 'alice's editor'","rejectedBy":[],"selected":true},
  {"identity":"unit 'battery settings'","rejectedBy":["host"],"selected":false}
]
```

The context is Alice on the workstation. The battery unit is valid but inactive there. If its host claim had no possible roster member, ordinary resolution would fail rather than merely mark it inactive.

The example constructs a trace with `resolvers.trace units context`, then projects the three fields above. Don't serialize an entire raw trace to JSON: claims can contain predicate functions, and `value` can contain data that isn't JSON-serializable.

For a scalar conflict, use `label` on the contributing units and read the path named in the error. A trace's `diagnosticText.leaf` can expose claim-check errors without demanding its result; it isn't a catch-all for predicate failures or merge conflicts.

## Where does a unit apply?

A matrix evaluates selection over known roster memberships:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix preferences.matrix.coverage.preMerge.paths
```

<!-- value: preferences.matrix.coverage.preMerge.paths -->
```json
{
  "lowPower":["x86_64-linux/laptop/alice"],
  "tools":["x86_64-linux/workstation/alice","x86_64-linux/workstation/sam","x86_64-linux/laptop/alice"]
}
```

These are top-level paths offered by selected units, before merging. A matrix doesn't merge payloads, so it won't prove that overlapping scalar values agree. Evaluate the actual result as well.

`mkResolveMatrix roster { units = units; }` uses only IDs in its default contexts. If a predicate needs extra host or user properties, pass `contextFor`. The [team example](../../examples/ownerships-team/team.nix) supplies its `host.mobile` field in both normal and matrix contexts.

## Report fields

`mkResolveTrace roster units context` and `mkResolveSystemTrace roster units context` return the same record shape:

| Field | Meaning |
| --- | --- |
| `value` | Merged configuration, with the ordinary resolver's errors when demanded. |
| `trace` | List of records, one per configuration-bearing unit in traversal order. |
| `mergeProvenance` | A tree of `{ path; contributors; children; }`. Root path is `""`; child paths are dot-joined. |
| `stageReports` | `leaf`, `tree`, and `survivors` each hold a list of `{ view; diagnostics; }` reports. Each `diagnostics` value is a list of [diagnostic records](advanced-reference.md#resolver-base-override). |
| `diagnosticText.leaf` | Rendered claim-check error text, or `null`. Other failures can still throw. |

Each entry of `trace` has these fields:

| Field | Shape |
| --- | --- |
| `key` | Structural position such as `"0/0"`. |
| `identity` | Label-based, source-based, or shallow-shape description. |
| `effectiveClaim` | Claims after nesting; set axes use `{ tag; set; }`, predicates remain functions. |
| `selected`, `rejectedBy` | Boolean and list of rejecting axis names. |
| `axisResults` | Axis name → `{ claim; selected; decision; details; }`. Decision is `"global"`, `"selected"`, or `"rejected"`. Set-axis details include `materializedMembers` and `satisfiable`; predicates have no member list. |
| `ctxRequirements` | Axis name → `{ key; required; available; }`; predicate axes have a null key and availability. |
| `checkResults` | Claim-check diagnostics for this unit. |
| `preMergeContribution` | `null` when rejected; otherwise `{ stage = "pre-merge"; meaning; offeredPaths; shape; }`. Paths are top-level keys, not final attribution. |

Provenance contributors contain `identity`, `owners` (effective claims), and optional `mergeProfile`. Lists are terminal nodes: provenance records contributing units, not an owner per element. A replacement can retain multiple contributors at its node while its child tree comes from the surviving right-hand value. Labels, source strings, claims, and path names are metadata you supplied; don't put secrets in them.

A matrix (`mkResolveMatrix` or `mkResolveSystemMatrix`) returns:

| Field | Shape and meaning |
| --- | --- |
| `units` | `leaf-N` → `{ key; identity; shape; }`, in the report's configuration-bearing traversal order. |
| `byContext` | Context key → `{ hostName; survivors; inactive; preMergePaths; }`; user rows also have `userName`. Survivors are unit keys; inactive entries are `{ key; rejectedBy; }`. |
| `coverage.units` | Unit key → list of context keys where it survives. |
| `coverage.preMerge` | `{ meaning; paths; }`, where `paths` maps top-level offered paths to context keys. |
| `hostDiffs` | `"left-id -> right-id"` → `{ units; preMergePaths; }`, each containing `leftOnly` and `rightOnly`. User contexts are combined per host for this comparison. |
| `display` | Roster display-name maps. |
| `dead` | Unit summaries with `reasons`: impossible claims, including incompatible known membership. |
| `neverSelectedInModeledContexts` | Unit summaries with context-keyed `rejections`; not proof of impossibility outside those contexts. |
| `indeterminate` | `{ unknownMembershipUsers; units; }` for unresolved membership and affected unselected units. |

User matrix keys are `host-id/user-id`; system keys are `host-id`. User rows enumerate known memberships only, while system rows cover roster hosts. Each dead reason has `kind` and `reason`, plus `axis` or `axes` when applicable. Report keys describe this traversal, so adding or moving units can renumber `leaf-N` entries.

Matrices classify impossible claims into `dead` rather than throwing those particular diagnostics. Other errors, including malformed units, ambiguous aliases, invalid scope, failing predicates, and custom checks, can still throw. They inspect identity, names, and shallow payload shape rather than merged values.

For the resolver signatures and `contextFor` arguments, return to the [reference](reference.md#resolvers). For a complete configuration that uses these reports, read [the team example](worked-example.md).
