# Dependency boundary

`src/dependencies.nix` initializes one corrected nix-effects value with the selected
library, then native Krisis with `{ lib, fx }`. The public factories, fixture
assembly and installed generic evaluator use this owner. The generic evaluator
embeds the selected source exports so it doesn't resolve another dependency graph
inside its isolated store. Its evaluator remains the selected nixpkgs `nix`.
The development shell now selects that same package explicitly.

`src/effects.nix` validates the retained Axiom result envelope, emits diagnostics in
order, and produces an explicit Checked value. Input values, diagnostic recovery
data and successful results use public `fx.state.mkThunk` and `forceThunk`. The
collector's continuation doesn't authorize dependent work. A failed result has no
value even when it contains only warnings. The declaration report boundary selects
this owner; traversal and other subsystems retain their existing algorithms.
The bridge shares one collecting-handler configuration. Its initial state is
immutable, so separate interpretations retain separate diagnostic histories.

`src/diagnostic-compatibility.nix` retains the old diagnostic record schema and
terminal presentation contract. It contains no effect interpreter. Default
reporters eliminate results through the native bridge. Injected old providers
override the old-facing operations, including reporter construction. Native Krisis
remains available to internal owners as `krisis.effects.native`, with its shared
effect instance at `krisis.effects.fx`.

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
| `validation` | Declaration traversal/output/resource stages and unmigrated subsystem composition | Retain until the owning stage migrates; default diagnostic reporters bridge once |
| `types` | Praxis schemas and fields | Retain Axiom type objects and `validateType` adaptation |
| `registry.compile` | Declaration registration, Ownerships descriptors/relations, Registry core, directory reservations, Furnish collisions/executors, theme renderers, Praxis ownership | Retain collision validation before indexing; each owner needs a later capability-specific decision |
| `phases.compile` | Ownerships engine | Retain phase dependency/order validation |
| `requirements.evaluate`, `requirements.observe` | Ownerships relations, Furnish executors, theme capabilities and runtime | Retain requirement evaluation; no diagnostic substitution |
| `canonical.qualified`, `canonical.path`, `canonical.join` | Ownerships axes/matrix/import/merge, Registry identities, program fields, Furnish identities, theme identities and diagnostic code qualification | Retain canonical encoding contracts |
| `sets.unique`, `sets.index` | Registry field constraints and Praxis parameter/schema validation | Retain ordering and index semantics |
| `identity.mk`, `identity.render` | Compatible `safeIdentity` projection | Retain label/source precedence and injected identity behavior |

No Axiom language implementation is imported. Native new Krisis owns report
interpretation, Checked/Outcome elimination, scope behavior and the shared effect
transport boundary. This change doesn't replace the compiler traversal or resource
collision algorithms.
