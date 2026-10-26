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
| Native type callbacks | Fixed checker configuration shared outside applications; completed native reports projected through blame adaptation to retained results | Lexicon callback correction designed, unimplemented and unqualified; Krisis unchanged |
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
cache or primed production reporter. The callback correction below keeps Krisis
at `c48e40834fe90299096d2988433b17f650c30c8a` and qualified Fx unchanged. No
dependency correction or private API is in scope.

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
for the correction ownership and future gates.

## Callback report projection correction

The merged [profiling report](../praxis-diagnostic-profile.md) supports removing
the callback's intermediate adapted-diagnostic computation. This is a designed,
unimplemented and unqualified correction. Keep configured native checking and its
collecting interpretation. Purely project the completed native Checked report
through Praxis blame adaptation into the retained callback result. Remove the
`fromDiagnostics` computation and `resultOf` interpretation used solely to build
that result. Keep enclosing schema-to-native composition, shared command
interpretations, graph selections and terminals.

The effects bridge owns a distinct projection operation taking a native Checked
report and a diagnostic mapper. Its name belongs to the implementation owner.
Share explicit Outcome/Checked constructor elimination with existing report
operations. Recover carriers only with the qualified `forceThunk`. Existing
`resultFromReport` continues recovering original diagnostics through thunked
context. Reject unknown or impossible constructors and Invalid or failed outcomes
without usable failure evidence. A retained failure has diagnostics and no value;
a resumed collecting-handler value never proves success.

For every mapped diagnostic, normalize through the existing compatibility mapping,
demand code then severity in their existing order, and use public native
`diagnostic.make` for required envelope validation. Preserve diagnostic/check order
before proceeding to the next check. Presentation and arbitrary context stay
deferred. Preserve factory participation and original input, predicate, mapper,
code, severity and factory exceptions. Do not deeply force diagnostics or
synthesize a native Report. Introduce no handler state, report format, diagnostic
runtime, generic framework or cache.

Scalar, choices, default and environment callbacks interpret native checking and
project directly to retained results. References compose native shape and
dependent body checking with `validation.andThen`; rejected shape suppresses
`param` demand and failures are projected once. Argument callbacks validate the
outer list before its members and preserve the string fast path. Probe each
nonstring reference once and share its result, retaining the original accepted
argument. On rejection, demand the reference probe and its adapted envelope before
evaluating the string fallback, but output string diagnostics before reference
diagnostics. Accumulate independent members in authored index order. Preserve
original successful values and opaque children; build fragments and concatenate
once. This is pure projection of completed observations, not generic Axiom-based
computation sequencing. Do not catch callback exceptions.

Preserve declarations, factories and overrides, extension/schema callbacks,
diagnostic origins, content and summaries, terminal recovery, failure state,
thunk transport and inactive/unrelated opacity. Command/selection sharing and
reached-only normalization remain protected. General `fromDiagnostics`,
`fromAxiom`, `resultOf` and `share` remain available to other consumers.

Historical functional, selected and profiling evidence does not qualify corrected
source. [Integration obligations](efforts.md#integration-effort) require a complete
distinct corrected manifest, lock/dependency identities, applicability map,
affected observations and combined gate before fresh cost readiness. Both reports
remain immutable history. Do not repeat profiling or initialization sensitivity,
set an emission-count target or claim a static speedup. Instrumented costs are
neither primary acceptance nor quantities to subtract. No priming, setup
subtraction, reduced demand or changed bounds is permitted. New cost exceptions
need explicit user approval.

This amendment grants no evaluator, version query, development shell, formatter,
qualification, functional gate, workload, new checkout, candidate import,
correction, integration, cleanup or adoption authority. Integration stays held
until verified publication and a fresh opener with actual authority.
