# Dependency boundary

The remaining migration contracts are published as the
[spec](nix-effects/spec.md), [architecture](nix-effects/architecture.md),
[effort ownership and candidate custody](nix-effects/efforts.md), and
[capabilities and acceptance evidence](nix-effects/capabilities.md).
They distinguish delivered behavior, the functionally qualified uncommitted Praxis
candidate, and performance acceptance deferred in full to a separate future
user-directed audit. Failed/missing cost evidence no longer blocks migration review
or architectural acceptance; no audit execution or performance pass is implied.

`src/dependencies.nix` initializes one corrected nix-effects value with the selected
library, then native Krisis with `{ lib, fx }`. The public factories, fixture
assembly and installed generic evaluator use this owner. The generic evaluator
embeds the selected source exports so it doesn't resolve another dependency graph
inside its isolated store. Its evaluator remains the selected nixpkgs `nix`.
The development shell now selects that same package explicitly.
Krisis is pinned to `c48e40834fe90299096d2988433b17f650c30c8a`, which shares
lazy checker configuration. Its qualified Fx source, patch and provenance are
unchanged. The generic evaluator embeds that Krisis source and its qualified Fx
export through the same dependency owner.

`src/effects.nix` validates the retained Axiom result envelope, emits diagnostics in
order, and produces an explicit Checked value. Input values, diagnostic recovery
data and successful results use public `fx.state.mkThunk` and `forceThunk`. The
collector's continuation doesn't authorize dependent work. A failed result has no
value even when it contains only warnings. Declaration reporting, Ownerships
orchestration, registered compiler traversal, Registry orchestration, selected
resource composition, theme preparation and Furnish compilation select this owner.
The bridge shares one collecting-handler configuration. Its initial state is
immutable, so separate interpretations retain separate diagnostic histories.

`src/diagnostic-compatibility.nix` retains the old diagnostic record schema and
terminal presentation contract. It contains no effect interpreter. Default
reporters eliminate results through the native bridge. Injected old providers
override the old-facing operations, including reporter construction. Native Krisis
remains available to internal owners as `krisis.effects.native`, with its shared
effect instance at `krisis.effects.fx`.

Ownerships author-key, scope and phase errors include plain strings. The bridge
normalizes this finite string/record vocabulary for native emission and protects
the original diagnostic in a thunk. Terminal callbacks recover that original
value. Code and severity are demanded before native envelope validation so a
throwing callback retains its exception. Presentation fields stay deferred.
Each demanded unit combines dependent author-key and unit-schema checks within
one interpretation. Ordinary resolution keeps its existing per-context work;
prepared resolution keeps its shared static half.

`finishWithReporter` uses native Checked/Outcome elimination by default. An
injected reporter's `finish` receives the retained Axiom result envelope through
the single compatibility owner. That terminal adaptation does not introduce
application-level Axiom sequencing.

`checkWithReporter` preserves the structural compiler check's boolean terminal
projection while returning its validated prepared entry internally. An injected
terminal's successful return is demanded and discarded at that check, as before.
`share` interprets a context-independent Checked validation once and replays its
diagnostics inside each selected context. Compiler scope checks use this operation
for emit-only validations; it is not an abort/recovery computation cache.

## Old operations

The mapping was read from Krisis revision
`730e7b58602807ad781c8c0f2009cecc8976532b`.

| Old export | Owner and mapping |
| --- | --- |
| `allowedSeverities` | Retained diagnostic vocabulary |
| `mkDiagnostic`, `mkDiagnosticFactory`, `qualifyCode` | Retained Axiom record/default interpretation and code qualification |
| `mkReporter` | Retained aggregate formatting hooks; native result elimination |
| `renderPlain`, `renderDiagnostics`, `throwDiagnostics` | Retained terminal text, header, separator and formatter contract |
| `summarizeDiagnostics` | Retained envelope-only count projection and malformed-input errors |
| `collectDiagnostics`, `optionalDiagnostic` | Retained diagnostic-list operations |
| `withErrorContext` | Original `builtins.addErrorContext` boundary |
| `renderPath` | Retained string/index path syntax |
| `validateType` | Retained Axiom type validation with old diagnostic adaptation; never passed to native `validation.check` |
| `safeRender`, `safeRenderWith` | Retained bounded scalar/list inspection and option interpretation |
| `safeShape`, `safeShapeWith` | Retained shallow name projection and option interpretation |
| `safeIdentity` | Retained label/source precedence through Axiom identity helpers |
| `suggest`, `suggestWith` | Native `suggest.nearest` with existing defaults or supplied bounds |
| `editDistance` | Selected library's Levenshtein operation |

The old record distinguishes optional omission from explicit null, merges factory
primary defaults when a call supplies null, and permits an empty primary record.
The adapter preserves those behaviors. Native diagnostic normalization is confined
to the report boundary; returned old diagnostics retain their original record
projection. Custom factories, renderers, summaries and reporters supplied by an old
provider remain observable in extensions and public factory results.
An empty old primary record becomes absent in native presentation. The retained
old diagnostic still has its original primary record.
Pure inspection and count projections retain their old control errors. Native
inspection rejects the same malformed options with different exception text.
Keeping the compatible pure projections avoids a second validation walk through
the native inspector. Native reports still obtain their summaries from Krisis.

## Retained Axiom capabilities

| Capability | Production owners | Disposition |
| --- | --- | --- |
| `schema.compile` | Declaration reports/definitions, Ownerships axes/surface/merge, Registry fields, Furnish core, TOML encoding, theme, Praxis fields | Retain the public field interpreter and its result bridge |
| `validation` | Retained schema/parse callbacks, compatibility result envelopes and lazy Praxis graph-node projections | Keep callback result construction at its boundary; registered compiler, resource plans, directory expansion, theme preparation, Furnish, Ownerships, Registry, Praxis and TOML encoder orchestration use native `all`/`andThen` and Fx |
| `types` | External old-facing type callbacks only | Praxis uses qualified native types; retain `validateType` for the published extension/override boundary |
| `registry.compile` | Declaration registration, Ownerships descriptors/relations, Registry core, directory reservations, Furnish collisions/executors, theme renderers, Praxis ownership | Retain collision validation before indexing; migrated owners adapt each result once at their operation boundary |
| `phases.compile` | Ownerships engine | Retain closed view/callback validation and registration order; share one prepared registration |
| `requirements.evaluate`, `requirements.observe` | Ownerships context requirements and relations, Furnish executors, theme capabilities and runtime | Retain requirement evaluation; no diagnostic substitution |
| `canonical.qualified`, `canonical.path`, `canonical.join` | Ownerships axes/matrix/import/merge, Registry identities, program fields, Furnish identities, theme identities and diagnostic code qualification | Retain canonical encoding contracts |
| `sets.unique`, `sets.index` | Registry field constraints and Praxis parameter/schema validation | Retain ordering and index semantics |
| `identity.mk`, `identity.render` | Compatible `safeIdentity` projection | Retain label/source precedence and injected identity behavior |

No Axiom language implementation is imported. Native new Krisis owns report
interpretation, Checked/Outcome elimination, scope behavior and the shared effect
transport boundary. Compiler preparation creates validated entries in one native
structural computation. Selected domain and metadata schemas adapt once, then
lowering and contribution validation compose within the context computation.
Resource schemas and grouped-link parse callbacks retain Axiom result contracts.
Selected plans adapt once before native composition. Directory expansion adapts its
reservation registry once and retains pure inventory and expansion algorithms.
Theme files validate per-block groups before adapter construction; Matugen validates
cross-declaration groups at their original per-group module boundary. Furnish uses
native shape, registry and artifact validation at their original terminal
boundaries. Its registries,
requirements and canonical identities retain their domain owners.
Interpretation follows demanded operations. Resource payload validation doesn't walk
directories, theme diagnostics don't generate sources, and Furnish preparation doesn't
run materializers. Static directory inventories remain shared per authored occurrence.

Ownerships set operations and roster projection remain pure. Set indexing would
force member tails that current short-circuit queries leave opaque. Its public
suggestion helpers retain their existing thresholds, ties and malformed-input
exceptions. Den roster/principal projection also stays pure, with no host
instantiation or Den user-body evaluation. Den's `drop` retains its injected
terminal diagnostic operation.

Furnish eliminates native Checked results with `finishComputation reporter.fail`.
Individual domain guards retain `failOne`, including its recovery return. Shape,
registry and artifact recovery values enter the same downstream operations as
before. Theme file groups use `checked diagnostics []` only on failure; successful
groups call no terminal. Matugen calls `finishWithReporter` for each group's
registration result and demands that return before constructing declarations.
Group concatenation preserves the first throwing terminal and later-group laziness.

TOML encoding adapts constructor field schemas once, then composes recursive
checks through native `all` and `andThen`. Its public `document` projection retains
the Axiom result envelope; generation uses the computation directly and preserves
injected reporter `finish` recovery. The pure renderer consumes the typed result
without effects. Raw TOML validation and retained-syntax merge remain native.

## Praxis boundaries

Praxis projects ownership before normalization. Public projection, command/task
lowering, parameter ordering, prompt validation and schema orchestration compose
native Checked computations. Literal argv bypasses parameter and interaction
construction. Each demanded command has one lazy interpreted result, shared by
namespace lookup, selected reachability, manifests and summaries. Namespace
children use the same boundary. Graph traversal stays pure and reached-only;
its final diagnostics enter one Checked computation per selection.

`src/praxis/type-checks.nix` owns the finite native blame mapping for scalar,
list, nullable and reference checks. It preserves old codes, messages, paths,
reasons and ordered union failures. Reference checking validates the outer
attribute names before `param`. The untagged string-or-reference choice is a
Praxis operation; native Either accepts tagged values and doesn't implement that
public input contract. Native validation never receives an Axiom type object.
Type descriptions are shared outside the code application. The internal
`fields.typeChecks code` factory owns native checker partial applications for each
fixed code/type combination. Schema and parameter owners bind their configured
operations once. Subject, authored path and input enter each value application;
validation, scoped failure state and diagnostic adaptation remain per call.
Constructing unused configured operations leaves code and values lazy. There is
no input/result cache. Successful native validation leaves unused locations and
opaque payloads deferred.
`effects.mappedResultFromReport` projects a completed native Checked report
through the Praxis blame mapper into a retained parse result. It shares explicit
Outcome/Checked elimination with recovery and `share`. Unknown or impossible
constructors and invalid/failed reports without diagnostics are rejected. Only
qualified carriers recover successful values. `resultFromReport` still recovers
original diagnostics from their thunked context.

Mapped diagnostics use the existing compatibility normalization. The bridge
demands code, then severity, then public native `diagnostic.make` for each envelope
before the next diagnostic or check. It returns the original mapped diagnostic;
presentation and arbitrary context stay deferred. Factory and mapper exceptions
aren't caught. References compose native shape and dependent body checking with
`validation.andThen` and project once. Arguments check their outer list first,
keep strings on the fast path and share one reference probe per nonstring member.
A rejected reference's envelope precedes string fallback demand, while returned
diagnostics keep string-before-reference order. Member fragments concatenate
once in authored order. Accepted arguments retain their original values.

The callback-only adapted diagnostic computation and reference probe/replay path
are removed. General `fromDiagnostics`, `fromAxiom`, `resultOf` and `share` remain
for their other consumers. No handler state, report format or result cache is
introduced. Native reports are projected before retained schema parse callbacks.
Argument, parameter and environment values remain opaque across report transport.

Praxis retains Axiom schema interpretation in `fields.nix` and collision
registration in `ownership.nix`. Its graph-node result projections use the shared
result adapter. Public terminal calls still route through `finishWithReporter`,
including injected `finish` recovery. Summaries read selected diagnostics without
building packages or demanding runtime package paths.

The residual result operations in Registry field parsers and grouped-link list
parsers belong to Axiom schema callback contracts. Registry traverses named
nested records with lexical diagnostic order and explicit null host exclusions;
grouped links preserve authored list indexes and duplicate diagnostics. Their
outer application orchestration already uses native Checked computations. The
compatibility owners retain schema-result construction, diagnostic formatting,
inspection control errors and external type callbacks. Context wrappers preserve
injected error-context operations and authored exception locations. These are
public compatibility boundaries, not separate effect instances.

Pure evaluation is supported with the selected nixpkgs Nix evaluator and
`pipe-operators`, with IFD disabled. Cross-system public-factory evaluation does
not establish native execution on that system. Operational proof is native
x86_64-linux. TOML parsing and retained-syntax merging still use TOML Kit; its
renderer is pure Nix. Coordinator and Praxis runtime protocols remain with their
existing native owners.

The final residual capability reconciliation retains these owners and removes no
protected callback or override. Registry's nested-result parsers and grouped-link
list parsing remain Axiom schema callback work; their outer orchestration is
native. Compiler scope preparation still consumes `share` in
`src/declarations/default.nix`. Praxis shares lazy interpreted command/selection
results rather than invoking that replay helper. The callback-only adapted report
and reference replay have no remaining production path in `type-checks.nix`.
Unmeasured scan/index or graph/preparation suggestions are not functional findings
and authorize no rewrite, cache or speed claim. This reconciliation changes no
production source or dependency.
