# Shared effects architecture

Lexicon keeps domain algorithms with their subsystem owners. Pure functions
transform domain values; computations describe validation and diagnostic work;
handlers interpret demanded computations at existing boundaries. New Krisis and
qualified nix-effects replace internal orchestration where their capabilities
fit. Public compatibility remains at one boundary.

This describes the accepted architecture. The [spec](spec.md) distinguishes
delivered behavior from the uncommitted Praxis integration, and
[capabilities](capabilities.md) records functional qualification, retained evidence
constraints and deferred performance acceptance. Immediate and assembled
performance acceptance is deferred in full to a separate future user-directed
audit, which is not authorized by this amendment. Failed and missing rows remain
failed and missing; they do not block functional migration review, commit preview
or architectural acceptance.

## Dependency assembly and lifetime

The delivered [dependency owner](../../src/dependencies.nix) imports Krisis's
public plain `qualifiedNixEffectsSource` with the selected library. It constructs
one Fx instance, initializes native Krisis with `{ lib, fx }`, and supplies that
same instance to the [compatibility bridge](../../src/effects.nix). Public
factories, fixtures and the [installed generic evaluator](../../src/praxis/generic.nix)
use this owner. The plain export exists; the historical proposal saying it was
missing is obsolete.

The generic evaluator embeds selected dependency source exports and invokes the
same owner inside its isolated source assembly. It does not resolve a second
dependency graph there. Its evaluator remains the selected nixpkgs `nix`.
Source-only library assembly must not introduce import-from-derivation, another
unpatched Fx instance or a Lexicon-owned copy of Krisis's correction.

Fx and the native/compatible views share the lifetime of their dependency
assembly. The bridge shares immutable collecting-handler configuration. Each
interpretation has its own diagnostic history and failure state. Sharing
configuration does not cache a previous input, successful result or report.
Separate public factory applications are not proof of identity of every lazy
native type allocation.

Qualified Fx transport remains unchanged by Krisis's published configured-checker
correction. The uncommitted Praxis type-check owner binds fixed type/code checkers
outside applications. Subject, authored path, value, predicate execution, native
failure state and blame adaptation remain per call. Unused configuration remains
lazy. No report initialization step belongs in production.

## Owners and data flow

| Owner | Domain responsibility | Composition and boundary |
| --- | --- | --- |
| Dependency assembly | Selected library, qualified source, native Krisis and compatible view | Supplies dependencies to factories and generic evaluation; consumers need no Fx argument |
| Compatibility bridge | Safe report elimination, retained result projections, compatibility envelope demand, terminal recovery and old provider participation | Adapt Axiom results once to native Checked; share constructor elimination between existing recovery and the implemented mapped-report projection |
| Ownerships | Descriptor/relation registration, claim algebra, selection, preparation, merge and coverage | Native context/validation orchestration around pure algorithms |
| Registry and Den | Canonical fleet records, membership, checked lookups and roster/principal projection | Interpret requested validation only; do not instantiate hosts or evaluate Den user bodies |
| Definitions and declarations | Registration, structural preparation, output/scope projection, selection and lowering | One registered traversal, native dependent validation, ordinary pure extension callbacks |
| Resources, themes and Furnish | Typed plans, inventories/reservations, source exclusion, destinations, manifests | Selected native composition and original per-group/terminal boundaries; native runtime adapters retain lifecycle |
| TOML | Typed encoding and pure generated text | Native validation composition; TOML Kit parses/merges; publisher performs live operations |
| Praxis | Selected command normalization, graph traversal, manifests/packages/apps/checks | Candidate native Checked composition and finite blame adaptation; graph algorithms remain pure and reached-only |

Dependency direction runs from public factories through assembly into subsystem
owners. Domain owners consume native validation and the shared bridge; the bridge
does not own command traversal, claim algebra, directory expansion or TOML
rendering. Runtime owners consume compiled descriptions. Pure evaluation does not
perform checkout creation, process execution or live filesystem reconciliation.

Declaration flow remains registration, structural preparation, requested output
projection, ownership selection, selected domain validation, lowering, contribution
validation and resource/native adaptation. Definitions compile once per configured
environment. Validate collisions before creating dispatch indexes. Declared nodes
are the only recursive traversal authority; native module bodies remain opaque.
Lower callbacks return ordinary contribution records under the existing
[definition contract](../../src/lexicon/definitions.md).

Static preparation stays lazy per authored occurrence and shared across contexts.
Context-produced records prepare within their selected slice. Selected values,
metadata, origins and preparation stay aligned after filtering. The bridge's
`share` replays context-independent emit-only Checked validation; it is not a
cache for arbitrary abort/recovery computations.

Resource composition keeps its fixed order: normalize selected themes, expand
directories using complete reservations and selected rules, lower final file/link
resources, then adapt theme runtime plans. Cross-subsystem destination checks
remain centralized in Furnish. Theme runtime modules retain user principals.
No whole-plan serialization or generalized extension dependency scheduler enters
this flow.

## Validation and compatibility

Use native `validation.all` for independent checks and `validation.andThen` for
dependent work, with `fx.bind`/`fx.map` for computations. `|>` remains ordinary
function application. Scoped context must restore sibling scope. Handler
registration rejects collisions and unknown effects retain the qualified failure
contract. Do not use private or experimental dependency namespaces.

The [dependency inventory](../dependencies.md) records delivered owners. Retain
Axiom field schemas and parse-result callbacks, collision-validating registries,
phase registration, requirements, canonical identities, ordered set helpers and
compatible identity projections where they own those contracts. Do not pass
Axiom type objects to native `validation.check`, validate one payload twice, import
Axiom's language implementation or build a parallel diagnostic runtime.

The bridge validates the retained result envelope and emits diagnostics in order.
Inputs, diagnostic recovery data and successful results cross interpreter state
and result boundaries in qualified `mkThunk`/`forceThunk` carriers. Terminal
callbacks recover original diagnostic values. Envelope demand preserves original
code/severity callback exceptions; presentation fields remain deferred. Default
reporters eliminate native Checked/Outcome values. Explicit old providers retain
their factory, formatting, summary, error-context and recovery operations at this
same boundary.

Praxis owns the finite type/reason vocabulary, authored blame adaptation and
retained schema callbacks. Krisis remains validation owner. The implemented
correction below projects completed native reports before returning retained
schema parse results. Scalar/list/nullable/reference checks preserve codes, paths,
reasons and ordered union failures. Malformed reference names fail before `param` payload
demand. An untagged string-or-reference choice remains a Praxis operation, not a
native tagged Either substitution. Each demanded command's lazy interpreted
result is shared by namespace lookup, reachability, manifests and summaries.

## Callback projection boundary

This boundary is implemented and functionally qualified. Fixed type/code checkers
stay outside value applications, with unused configuration lazy. Every demanded application
keeps its own input, predicate execution, native failure state and authored blame.
The collecting-handler configuration remains shared and immutable; each native
interpretation produces its own report. A completed report and the retained
projection have that application's lifetime, with no input/result cache.

Scalar, choices, default and environment callbacks run configured native checking
under the existing collecting interpretation. The bridge then purely projects the
completed native Checked report using Praxis's diagnostic mapper. The bridge
operation `mappedResultFromReport` takes the mapper and completed report.
The bridge shares Outcome/Checked elimination rules with its existing operations,
while `resultFromReport` still recovers original diagnostics from thunked context.
Only known constructors and qualified `forceThunk` recovery permit a value.
Invalid or failed outcomes without usable failure evidence and impossible
constructors are rejected. Failure results contain diagnostics and no value.

Mapped diagnostics pass through the existing compatibility mapping. Demand code
then severity, in their existing order, before public native `diagnostic.make`
validates the envelope. Settle each diagnostic/check's required envelope before
the next check. Keep message, locations, related entries, notes, help and arbitrary
context deferred. Preserve original mapper and factory exceptions as well as
input, predicate and code/severity exceptions. Do not deeply force the diagnostic
list, manufacture a Report or interpret an adapted-diagnostic computation merely
to obtain a callback result. This boundary needs no new handler state, report
format, diagnostic runtime, generic framework or cache.

References keep native shape and dependent body checking composed with
`validation.andThen` before interpretation and projection. Shape rejection leaves
`param` and extra values opaque. Project that native failure once. Arguments first
validate the outer list. String members retain their fast path. Probe a nonstring
reference once and share the projected result; success retains the original
argument. On rejection, settle the reference probe and adapted envelope before
evaluating the string fallback. Output remains string diagnostics then reference
diagnostics. Accumulate independent member fragments in authored index order and
concatenate once, keeping accepted values and opaque children intact.

This finite callback operation projects completed observations. Native computation
composition still belongs to enclosing schema-to-native work, shared command
interpretations, graph selections and terminals. It isn't generic Axiom-based
sequencing. Remove the callback's adapted-report `fromDiagnostics`/`resultOf` path
and the reference `resultOf`/`fromAxiom` probe/replay cycle. Keep general bridge
operations for other consumers and introduce no switch or parallel implementation.
Existing qualified carriers protect arbitrary inputs, results and recovery data
across the complete transport path. Preserve old-reporter recovery and factory
participation, command/selection sharing and reached-only normalization.

Krisis stays at `c48e40834fe90299096d2988433b17f650c30c8a` and qualified Fx stays
unchanged. Existing dependency and compatibility source outside the explicit
[correction overlay](efforts.md#correction-ownership-and-qualification) is read-only.
No private API or dependency correction is opened.

## Preserved algorithm and runtime boundaries

Raw authored-name narrowing still precedes alias canonicalization. Custom merge
callbacks retain their order and need not be associative. Ownerships matrix output
remains pairwise. An index must not force member tails that short-circuit queries
leave opaque. Source hypotheses about scans, indexes and graph/preparation work
are not established speedups or mandatory rewrites.

Furnish schema 3 and Praxis manifest 2 remain unchanged. The coordinator, runner
and TOML publisher retain live lifecycle ownership. TOML's pure renderer joins
fragments over typed values and preserves store context; TOML Kit retains parsing
and concrete syntax. A renderer does not establish parser or publication parity.

The completed [initialization report](../praxis-diagnostic-cost.md) found public
empty-success report initialization insufficient. The later
[profiling report](../praxis-diagnostic-profile.md) establishes the callback
round-trip source boundary. The correction above is the supported Lexicon design;
it doesn't assign total cost between Krisis and Lexicon or prove cost acceptance.

## Diagnostic attribution boundary

The maintained `verification/components/observe.py` owns evaluator capture,
complete-output validation and release, including merged instrumentation capture.
The merged `verification/components/profile-contracts.py` owns instrumentation assertions;
`verification/components/README.md` documents the maintained interface and
`verification/praxis-diagnostic-profile.md` records the immutable evidence.
[Effort ownership](efforts.md#source-position-and-sampled-stack-evidence-effort)
binds the frozen dispatcher/fixture identities and read-only source boundary.
The observer/README overlap was reconciled before combined qualification.
The maintained observer keeps the published instrumentation, deadline, record and
validator capabilities; the reconciled guide documents the combined interface.

Separate setup/checker construction, checker application, report emission and
collection, Praxis adaptation, and graph/result transport. Preserve unclassified
stacks. Do not attribute all interpreter descendants to an ancestor caller.
Counts identify demanded source-position applications, not individual closure
instances. Samples locate observed execution, not exact initialization cost or
temporal first emission. Neither provides per-component peak RSS. Disclose
counter-mode final collection and instrumentation allocations.

Growing setup counts with matching repeated-construction stacks require tracing
the responsible caller. Lexicon assembly and dependency-internal rebuilding are
different owners. Bounded setup with native checking/failure work requires source
inspection separating required per-input checking from avoidable repeated work.
Required checking alone establishes no defect or exception.

Adaptation/transport evidence needs a source-grounded explanation connecting
repetition to the actual Lexicon boundary owner. Bounded setup demanded beneath
emission supports only that narrower first-demand claim. Dominant stacks alone
do not prove correction ownership. Keep mixed ownership explicit. Disagreeing
counters/stacks, changed results, ambiguous frames or insufficient sampling leave
attribution unresolved. Bounded inconclusive closure grants no automatic
repetition, correction, integration or cost exception.

A future demonstrated dependency correction requires amended published Krisis
contracts first, then qualification, an immutable commit and verified portable publication
before Lexicon's pin/lock refresh and affected qualification. No Krisis correction
scope is granted here.

## Functional closure and performance deferral

Functional migration retains native checking, required envelope validation,
shared command/selection results and terminal recovery. No remaining diagnostic
validation is removed by the acceptance amendment. Axiom schemas/parse results,
registries, phases, requirements, canonical and ordered-set operations, and
old-facing factories/inspection/reporting remain with their actual owners in
[dependencies](../dependencies.md). The superseded callback adapted-report and
reference probe/replay implementation is removed; general bridge operations stay
available to their remaining consumers.

The user's decision defers all immediate and assembled performance acceptance.
The Lumi raw-4 wall/RSS failures and missing corrected selected/raw16/raw64/assembled
primaries remain recorded in [capabilities](capabilities.md#current-performance-gaps).
They impose no cost-blocking closure or mandatory cost-decision-packet requirement
on this migration. No performance pass, unavoidable-overhead claim, new exception
or result from the future audit follows. Original bounds, exact historical
tradeoffs, baselines and source/lock evidence remain intact.

The source-only remaining-diagnostic-boundaries assessment and all performance
investigation are stopped. Its source reads and any partial work are preserved.
A future audit requires separate user direction and authority. It is not a formal
dependency limit, automatic successor phase or limit-reopening opener. Functional
findings still require ordinary correction or a precise protected-contract/scope
ruling. Consolidated review, independent quality review, architect review,
affected qualification and commit approval remain in this integration phase.
