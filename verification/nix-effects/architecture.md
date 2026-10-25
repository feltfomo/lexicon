# Shared effects architecture

Lexicon keeps domain algorithms with their subsystem owners. Pure functions
transform domain values; computations describe validation and diagnostic work;
handlers interpret demanded computations at existing boundaries. New Krisis and
qualified nix-effects replace internal orchestration where their capabilities
fit. Public compatibility remains at one boundary.

This describes the accepted architecture. The [spec](spec.md) distinguishes
delivered behavior from the uncommitted Praxis integration, and
[capabilities](capabilities.md) records acceptance gaps.

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
| Compatibility bridge | Retained result and diagnostic projections, terminal recovery and old provider participation | Adapt Axiom results once to native Checked; interpret and eliminate reports at existing terminal boundaries |
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

Praxis's candidate adapts native blame once before returning retained schema parse
results. Scalar/list/nullable/reference checks preserve codes, paths, reasons and
ordered union failures. Malformed reference names fail before `param` payload
demand. An untagged string-or-reference choice remains a Praxis operation, not a
native tagged Either substitution. Each demanded command's lazy interpreted
result is shared by namespace lookup, reachability, manifests and summaries.

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

The diagnostic cost could involve report-policy/handler initialization, first
emission or workload-dependent checking/adaptation/re-emission. Current evidence
does not establish individual allocation cost or correction ownership. The
[diagnostic effort](efforts.md#diagnostic-evidence-effort) observes public report
initialization sensitivity before any architectural remedy. A demonstrated
dependency cause requires amended published Krisis contracts before dependency
work, then a qualified immutable publication before Lexicon's pin join.
