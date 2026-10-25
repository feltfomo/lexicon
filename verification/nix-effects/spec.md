# Remaining nix-effects migration contract

The accepted target is one shared qualified nix-effects instance and new Krisis,
with Lexicon's public declarations and subsystem boundaries preserved. The first
five migration units are delivered. Praxis is an uncommitted, functionally reviewed
candidate with blocked performance acceptance. Publishing this contract does not
adopt that candidate or authorize experiments.

Use [architecture](architecture.md) for owners and lifetimes,
[efforts](efforts.md) for exact ownership and sequence, and
[capabilities](capabilities.md) for observed results, accepted tradeoffs and gaps.
The [public API](../../reference.md),
[declaration syntax](../../src/lexicon/syntax.md) and
[definition contract](../../src/lexicon/definitions.md) remain the consumer and
extension contracts.

## Capabilities and status

| Capability | Accepted behavior | Publication status |
| --- | --- | --- |
| Dependency assembly | Public factories and installed generic evaluation use one dependency owner and shared qualified Fx | Delivered |
| Ownerships and fleet | Native validation orchestration around pure selection, merge, roster and lookup algorithms | Delivered, with scoped startup exceptions |
| Registered compiler | One registration/traversal pipeline for built-ins and external definitions, selected output bridges and shared static preparation | Delivered |
| Resources and Furnish | Native checked composition, common destination checks, original origins and terminal recovery boundaries | Delivered |
| TOML | One pure generated-value renderer; TOML Kit owns parsing, validation and retained-syntax merge; publisher owns live writes | Delivered under the parser fallback and standalone closure tradeoff |
| Praxis | Native Checked ownership, normalization, schema/parameter and graph-result composition; pure reached-only traversal | Uncommitted reviewed work |
| Native type callbacks | Fixed checker configuration shared outside applications, native blame adapted once to retained schema results | Published Krisis correction; Lexicon candidate integration remains uncommitted |
| Final cost acceptance | Unchanged immediate and assembled component bounds, or separately approved precise tradeoffs | Blocked by diagnostic size 4 and missing primary results |

## Public entry points

Preserve the names, currying, defaults and sparse outputs of `toml`, `ownerships`,
`registry`, `den`, `lexicon`, `program`,
`programDirect`, `programOwnerships`, `programDen`, `furnish`, `furnishRuntime`,
`praxis`, `praxisAdapters`, `report` and `mkCoordinator`. Their argument and result
contracts, including supported dependency overrides, remain in the
[public API](../../reference.md). No consumer acquires a
required Fx argument. Legacy Program calls remain thin translators to the single
canonical compiler.

`lexicon.configure` returns the existing `forDen`, `forRoster`, `forTarget`,
`withResolvers` and configured Ownerships API. Extensions retain
`{ lib, axiom, krisis, definitions }`, Axiom field specifications, registration
order and ordinary contribution-returning `lower` callbacks. The old-facing
Krisis operations and explicit old providers continue through one compatibility
boundary. Accepting an override must preserve its observable participation.

Praxis keeps its [declaration and CLI API](../../src/praxis/reference.md),
including selected manifests, packages, apps, checks, diagnostics and summaries.
Generated and installed generic CLIs retain both installed declaration layouts,
project-lock behavior, command arguments and manifest version 2. `_prepareOnly`
remains internal. Furnish keeps schema 3 and its native coordinator lifecycle.
The Praxis runner retains process groups, signals, terminal restoration, locks,
deadlines and child reaping.

## Failure and forcing contracts

Independent checks accumulate diagnostics in the existing order. Dependent work
runs only after a valid parent. A collecting handler's resumed value is not proof
of validity. Eliminate Checked and Outcome before using successful values; an
invalid result has no usable success payload. Preserve diagnostic codes, severity,
authored paths and indexes, messages, record and summary projections, aggregate
headers, and injected terminal dispatch and recovery returns.

| Operation | Permitted demand and protected boundary |
| --- | --- |
| Registration and structural preparation | Validate vocabulary, collisions, immediate containers, annotations and scope, including structural errors on inactive declarations. Do not inspect native bodies or inactive domain values. |
| Selection and output projection | Select ancestors, context and output before invoking domain callbacks or validating their payloads. Home Manager evaluation must not invoke resource callbacks with Home Manager config. |
| Context callback | Invoke at its registered boundary in the selected context. Validate the returned shape at the original authored path. Returned claims constrain the result and descendants but cannot prevent the invocation that produced them. |
| Preparation | Share lazy static preparation per authored record occurrence. Prepare callback-produced records within their selected context. Directory override names remain reserved even when inactive; this structural exception does not permit forcing inactive sources. |
| Resource composition | Validate selected plans, preserve principal and authored origin, and use common Furnish containment/collision checks. Do not serialize or deeply force a whole plan between pure stages. |
| Praxis selection | Normalize only selected commands and reached graph nodes. Unrelated namespace children, outputs, packages, runtime paths and opaque success payloads stay deferred. Diagnostics and summaries must not build packages. |
| Effect transport | Protect arbitrary inputs, recovery data and successful values with the qualified dependency's thunk carriers across the complete state/result path. Demanding one projection must not force opaque siblings. |
| Callback exception | Preserve the original exception with context at the expression actually demanded. Do not convert arbitrary exceptions into validation failures. |

Terminal boundaries are part of failure behavior. Furnish retains `fail` for
shape/registry/artifact finishing and `failOne` for individual guards, including
their recovery returns. Theme files finish failing groups individually and call
no terminal on successful groups. Matugen demands and discards each group's
`finish` return before declaration construction. Later groups remain lazy after
the first throwing terminal. Within-group independent checks still accumulate.

Praxis's candidate type-check owner keeps fixed type/code configuration outside
per-value calls. Subject, authored path, input, predicates, failure state and
blame adaptation remain per application. There is no successful-input/result
cache or primed production reporter. Qualified Fx is unchanged by the published
configured-checker correction. Diagnostic correction ownership remains open until
evidence establishes attribution.

## TOML and runtime boundaries

The [TOML API](../../src/toml/reference.md) retains constructors, source
pass-through, file derivation returns, TOML 1.1 behavior and retained syntax.
Generated values use one pure renderer. Constructor shape/type/placement errors
fail during evaluation. Raw literal/document syntax and range errors fail during
the build; each original literal validates independently as well as within the
final document. Generated file inputs remain opaque during evaluation, without
import-from-derivation.

CLI generation invokes that same packaged renderer using the consuming evaluator
and JSON data. Merge and publish start no evaluator. TOML Kit remains the parsing
and retained-syntax owner. The publisher keeps locking, writes, replacement,
durability, reload and failure recovery. This is not a claim that the complete
TOML subsystem is pure.

## Remaining acceptance

Final integration must reconcile every residual Axiom/old-facing operation with
its actual protected capability owner, preserve the failure and forcing contracts
above, and qualify the final immutable dependency graph. Immediate diagnostic
size 4 is still a wall/RSS failure. Raw diagnostic 16, a complete raw-64 primary
comparison and all assembled primaries are absent. A sensitivity result cannot
substitute for raw acceptance or approve a cost exception. See
[capabilities](capabilities.md) for exact observations and [efforts](efforts.md)
for the profiling prerequisite and gates.

## Diagnostic attribution amendment

The [initialization report](../praxis-diagnostic-cost.md) is merged. Both
initialized cells exceeded the unchanged wall/RSS bounds; the raw-64 experiment
was interrupted. The bounded report phase is complete, attribution remains open
and migration acceptance is incomplete. Do not complete or repeat initialization
sensitivity. Observe where the unchanged complete workload performs work.

The next proposed evidence asks whether additional candidate work lies in
repeated configuration construction, native checking/failure handling, Praxis
blame adaptation or retained-diagnostic transport/re-emission, and which source
owner controls demonstrated repetition. Use the exact frozen candidate and
archived immediate baseline with unchanged locks, Nix 2.34.8 and the maintained
`praxis-diagnostics` fixture at sizes 4 and 64. Demand complete codes, paths and
summary, all `2*N` diagnostics and the existing unrelated poison. Initialization
stays disabled.

Each source/size combination has separate ordinary capture, supported flamegraph
sampling at 1000 Hz, and source-position counting with `NIX_COUNT_CALLS` and
`NIX_SHOW_STATS` and a unique statistics destination. Never combine sampling and
counting in one evaluator. Retain original source positions and map attributed
frames to exact source bytes. The [architecture](architecture.md#diagnostic-attribution-boundary)
defines attribution limits; [efforts](efforts.md#source-position-and-sampled-stack-evidence-effort)
defines finite qualification, ownership and stop rules.

This amendment grants no evaluator, version query, qualification, functional gate,
worktree creation, correction, integration, cleanup or adoption authority.
Instrumented wall/RSS is recorded cost, not primary acceptance, an exact overhead
estimate or a quantity to subtract from raw results. Unchanged bounds and complete
demand remain protected; no production priming or setup subtraction substitutes
for acceptance. New cost exceptions need explicit user approval.
