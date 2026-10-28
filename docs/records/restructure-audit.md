# Audit of the functional architecture proposal

Audited file: [the research proposal](restructure-proposal.md) (cited as `P:<line>`). Every verdict below was
checked in source during this pass, at these pins:

| Source | Pin | Path read |
| --- | --- | --- |
| Lexicon | `main` at `37a898c` | `/home/feltfomo/Projects/lexicon` |
| Krisis | `c48e408` (flake.lock narHash `sha256-mY7wl3...` matches the store path) | `/nix/store/m1mby1jivsmf98g3w5fwxm8m78xgph80-source`, live checkout HEAD is the same commit |
| nix-effects | vendored in that Krisis | `.../vendor/nix-effects` |
| Den | v0.19.0 | `/nix/store/7pv5ph507f0rhx90g76h26hfcxakwgdr-source` |
| nixpkgs | `b7c2ada94fe99c15b0dbcf4d11fd7850b957a436` (Lexicon flake.lock) | `/nix/store/1dffznc7fgw6xnzssy1h4waxz63i11qa-source` |
| skadi | `707f5bf` | `/etc/skadi` |

Verdicts: **confirmed**, **wrong**, **partly right**, **unverifiable** (not settled by source read
in this pass). Paths without a prefix are Lexicon paths. `K/` is the Krisis store path, `NE/` the
vendored nix-effects, `D/` Den, `NP/` nixpkgs.

## Headline findings

1. The proposal puts the Furnish collision check in a per-principal `settle plans` stage
   (P:234). It isn't there today. The cross-declaration, cross-principal collision index runs inside
   the coordinator NixOS module over the module-system-merged `lexicon.furnish.declarations` list
   (`src/furnish/runtime.nix:68-75`, `src/furnish/core.nix:401-421,711-751`). That's the only place
   two different `lexicon { }` values meet. Any design that moves it into a per-slice stage loses
   cross-aspect collisions.
2. The settings edge adapter would break skadi. `lexicon.furnish.state` is a native option of the
   coordinator module (`src/furnish/runtime.nix:126-150`) that skadi reads back in its own assertions
   (`/etc/skadi/modules/system/impermanence.nix:38-63`). An option type whose merge returns a list
   of definitions (P:423-427) changes `config.lexicon.furnish.state.path` into a list. It's service
   configuration consumed at activation, not a compile-time Lexicon setting.
3. The lead's claim 1 is right about `fx.types.Record` (closed) and wrong that `RecordOpen` is an
   alternative: it's defined in `NE/src/types/constructors.nix:461` but isn't exported from public
   `fx.types` (evaluated below).
4. The lead's claim 4 (two walkers should be a dated limit) is wrong in framing. Dating it means
   dropping the Den host or replacing Den's walker, and either breaks skadi's batteries and quirks.
   The fix is to stop promising walker parity and make `lexicon { }` compile to plain class-keyed
   aspect fragments in both hosts, so only the portable aspect subset needs conformance.
5. The lead's claim 3 is partly right. `nixos` has two meanings for an author, but the ambiguity
   only bites in the proposal's walker model, where a walker must tell a `lexicon { }` value from a
   plain aspect. Today `lexicon { }` already returns native class modules
   (`src/lexicon/default.nix:142-198`), so the walker never sees Lexicon's `nixos`.
6. Failure behavior would change silently. Lexicon throws a rendered report at the forced bridge
   expression today (`finishComputation`, used in 20 call sites). The proposal routes module hosts
   through `k.nix.module` assertions (P:268-270), which defers failure to toplevel assertion checks
   and needs a fallback value for the failing slice.
7. Dropping Axiom is a public extension API change the proposal doesn't name. Block `fields` and
   `metadata` are Axiom field specifications by contract (`src/lexicon/definitions.md:14,30`), and
   `axiom.schema.compile` is the most used Axiom entry point (11 sites). The bookmarks example
   (P:309) silently switches to `T` types.
8. Lexicon has no single `fx` instance across public entry points. Each `lib.*` call reruns
   `dependenciesFor` (`flake.nix:29-39,57`), which re-applies the qualified nix-effects source
   (`src/dependencies.nix:8`). skadi calls three factories (`outputs.nix:5,11,12`).
9. `core.unfold` over `builtins.genericClosure` (P:552) can't give depth-first pre-order (P:458).
   `genericClosure` is breadth-first: evaluated on a tree `a -> [b c]`, `b -> [d]` it returns
   `[ a b c d ]`, not `[ a b d c ]`.

## Krisis gaps (P:583-623)

| # | Claim | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Files call `krisis.mkDiagnosticFactory { codePrefix }` from the compatibility layer, and nothing lists a subsystem's codes | confirmed, with an omission | 17 call sites, e.g. `src/declarations/report.nix:7`, `src/furnish/core.nix:30,49`; defined `src/diagnostic-compatibility.nix:181-210`. Omission: native Krisis already has `diagnostic.factory { namespace; severity; primary; }` (`K/docs/api.md:243-266`, `K/src/diagnostics.nix:121`). The real gap is only a closed code list, not a factory |
| 2 | Authored values are untagged; `T.Variant` needs `_tag`; these go through hand-written checks | confirmed | `K/docs/api.md:441`; `K/src/validation.nix:56`. `src/lexicon/resources.nix:138-183` and `syntax.md:53-56` show list-or-function and record-or-function fields. Note `fx.types.anyOf` (`NE/src/types/refinement.nix:177`) is a predicate combinator, not a type union, so it doesn't close the gap |
| 3 | No homogeneous attrset type; `T.Record` closed, `T.Attrs` doesn't inspect values | confirmed | `K/docs/api.md:432,438`; `K/src/validation.nix:37-76` admits no `AttrsOf`. Public `fx.types` has none either (attribute list evaluated below) |
| 4 | `effects.nix` uses `axiom.validation.map`; `praxis/fields.nix` hand-rolls `mapChecked`/`map2Checked` | partly right | The `axiom.validation.map` use is in `src/dependencies.nix:27`, not `effects.nix`. `src/praxis/fields.nix:11-15` confirmed. Missed: `src/toml/encode.nix:9` hand-rolls `mapChecked` too |
| 5 | `report.withContext` merges primary fields, so an inner path replaces the outer one | confirmed | `K/src/diagnostics.nix:98-110` (`mergeLocation = base // call`), `K/docs/api.md:364-375` |
| 6 | `effects.nix`'s `share` hand-rolls report replay | confirmed | `src/effects.nix:214-223`; used at `src/declarations/default.nix:175` |
| 7 | `eliminateWith`/`checkedFromReport` and `diagnostic-compatibility.nix` implement finish with impossible-constructor throws | confirmed | `src/effects.nix:138-190`, `src/diagnostic-compatibility.nix:301-327`. Krisis strict mode throws only the first error (`K/docs/api.md:387-390`), so a finish that renders all visible diagnostics is a real gap |
| 8 | Krisis's module example wraps `unsafeGetAttrPos` by hand | confirmed | `K/examples/module.nix:9`, `K/docs/api.md:686` |
| 9 | Dedupe by key, only if replay leaves duplicates | unverifiable | Duplicates are plausible: `share` re-emits the same static report in every slice (`src/declarations/default.nix:175`) and each bridge invocation is a separate report. Not measured |

Hand-rolled helpers the proposal missed:

- Lexicon paths are lists of strings and integers rendered into `primary.label`
  (`krisis.renderPath`, `src/type-compatibility.nix:7-21`; uses at `src/declarations/report.nix:16,32`,
  `src/toml/encode.nix:18`). Krisis locations want structured `path` segments
  (`K/docs/api.md:86-109`). Gap 5 only helps once Lexicon emits structured paths.
- `src/inspection-compatibility.nix` (`safeRender`, `safeShape`, `safeIdentity`) maps onto Krisis
  `inspect.value`, `inspect.shape`, `inspect.identity` (`K/docs/api.md:514-576`). The proposal's
  "Krisis inspect already covers it" (P:632) is confirmed.
- `src/type-compatibility.nix:23-59` adapts Axiom type objects, not `fx.types`. It goes away with
  Axiom, not with a Krisis upgrade.

## The `fx.types.Record` question (lead claim 1, P:844)

- `fx.types.Record` is closed. `NE/src/types/constructors.nix:111` is `Record = mkRecordType { open = false; }`.
  Evaluated: `(fx.types.Record { a = fx.types.Int; }).check { a = 1; b = 2; }` is `false`.
- The README comment "Record with typed fields (open — extra fields allowed)" at `NE/README.md:295`
  is stale.
- Krisis `T.Record` is `fx.types.Record` wrapped (`K/src/validation.nix:53`). The two can't differ.
- `RecordOpen` exists (`NE/src/types/constructors.nix:461`) but `builtins.attrNames fx.types`,
  evaluated with the pinned nixpkgs lib, doesn't contain it. It isn't public API, so AGENTS.md's
  stable-API rule rules it out. The lead's reading is right about Record and wrong to offer
  `RecordOpen` as a choice.
- Also wrong in both the proposal (P:144) and `docs/efforts/restructure.md:61`:
  `T.oneOfStr` isn't a Krisis type. `fx.types.oneOfStr` is a kernel predicate
  (`NE/src/types/refinement.nix:246`), used as `T.refined "Renderer" T.String (fx.types.oneOfStr [ ... ])`,
  which Krisis admits (`K/docs/api.md:446-449`).

## File-mapping table (P:625-678)

All 63 listed source paths exist. Verdicts per row group:

| Rows | Verdict | Evidence |
| --- | --- | --- |
| `dependencies.nix -> core/effects.nix` | confirmed | `src/dependencies.nix:8-9` builds the `fx` instance and native Krisis |
| `effects.nix`, `diagnostic-compatibility.nix`, `inspection-compatibility.nix`, `type-compatibility.nix` deleted | confirmed | See Krisis gaps |
| `declarations/*` to `systems/engine/*` | confirmed | node-kind chains at `src/declarations/definitions.nix:408-421`, `src/declarations/traversal.nix:159-187`; `traversal.nix:387` already dispatches `cases.${node.kind}` |
| `lexicon/default.nix` split into configure, plain host, Den host | partly right | `forRoster`, `forTarget` and `withResolvers` aren't plain-host concerns; they're bindings any host uses (`src/lexicon/default.nix:219-301`). `bind` (`:43-201`) is the bridge owner both hosts share |
| `lexicon/resources.nix -> subsystems/furnish/settle.nix` | partly right | It also owns theme normalization and directory expansion (`src/lexicon/resources.nix:91-105,187-225`), which are theme and directory concerns |
| `lexicon/runtime.nix -> subsystems/furnish/emit.nix` | partly right | It's the host-side assembly that imports the coordinator, matugen and composition modules and fans theme entries out per principal (`src/lexicon/runtime.nix:25-80`). It's the per-slice emit that hands off to the host-wide reduction, not Furnish's own emit |
| `furnish/contract.nix -> systems/services/coordinator/contract.nix` | confirmed | Imports only `lib` and `axiom` |
| `furnish/runtime.nix -> systems/services/coordinator/module.nix` | wrong | The module imports Furnish core and runs `furnish.compile` with the collision index (`src/furnish/runtime.nix:16-20,68-75`). A system importing a subsystem breaks the proposal's own layer table (P:93) |
| `furnish/target.nix -> core/paths.nix` | partly right | It owns the coordinator's target record `{ kind; path; }` and materialization (`src/furnish/target.nix:12-20`, used at `src/furnish/runtime.nix:49`). Only `externalPath` is a generic path predicate |
| `program/theme/*` to `subsystems/theme/` | confirmed | `matugen-runtime.nix:16-17` and `composition-runtime.nix:20-21` import Furnish's contract and files, so theme requires furnish |
| `praxis/adapters.nix` split | confirmed | `src/praxis/adapters.nix` is 16 lines; `fromDen` reads `adapter.roster` |
| `den.nix` split, `drop -> compose/exclude.nix` | partly right | Den has its own structural `excludes` key (`D/nix/lib/aspects/fx/key-classification.nix:15`). `drop` is an includes filter for the installer (`/etc/skadi/modules/installer/target.nix:17-22`), not Den's exclusion |
| `registry* -> compose/entities.nix` and plain host; skadi doesn't use it | confirmed for skadi | grep of `/etc/skadi` finds no `lib.registry`. It's still a public API (`reference.md:11`) |
| Axiom identity, canonical names and registries move to core | partly right | Also used: `axiom.schema.compile` (11 sites), `axiom.requirements.evaluate/observe` (`src/furnish/core.nix:586`, `src/ownerships/engine.nix:445`), `axiom.phases.compile`, `axiom.sets.*`. None of these has a stated home |

## skadi

| Claim | Verdict | Evidence |
| --- | --- | --- |
| helix aspect snippet (P:686-694) | confirmed, abridged | `/etc/skadi/modules/editors/helix/default.nix:1-42`; the real file passes `sharedWith = config.skadi.theme.noctaliaCompatibleRenderers` |
| hyprland mixes `{ includes } // lexicon { ... }` (P:703-710) | confirmed | `modules/desktop/compositors/hyprland/default.nix:97-110` |
| `outputs.nix` binds `denApi`, `lexicon`, `furnishRuntime` (P:765-772) | confirmed | `/etc/skadi/outputs.nix:5,11-13` |
| `impermanence.nix` imports `furnishRuntime` to set `lexicon.furnish.state` | confirmed | `modules/system/impermanence.nix:1,23,30-34` |
| "keeps `lexicon.furnish.state` as written" under the adapter | wrong | The same file reads `config.lexicon.furnish.state.path`, `.durability` and `.enable` in assertions (`:38-63`). The list-returning adapter type breaks those reads |
| coordinator module has `key = "lexicon/furnish/runtime.nix"` | confirmed | `src/furnish/runtime.nix:124` |
| `den.default` sets `stateVersion` | confirmed | `/etc/skadi/modules/den.nix:19-20` |
| skadi uses `den.quirks.persistence` | confirmed | `modules/den.nix:16`; producers at `system/networking.nix:3`, `desktop/display-managers/sddm.nix:3`, `desktop/shells/noctalia/greeter.nix:10` |
| skadi uses Den batteries | confirmed | `modules/users/feltfomo.nix:8-10`, `owner.nix:5-6`, `grandpa.nix:6` |
| `provides` appears only in a comment | confirmed | `modules/users/owner.nix:10` is a comment; no `hasAspect`, `meta.guard` or `__findFile` |
| `flake`, `host`, `user`, `home` cover skadi | unverifiable | Den's kinds weren't enumerated for skadi in this pass |
| skadi uses `lib.praxis` and `denApi.mkTarget/drop/hostAspects` | not claimed, true | `modules/flake/praxis.nix:6`, `modules/installer/target.nix:17-22`. The proposal's `denApi = host` (P:784) must keep these three |

## forDen and the bridges today

| Claim | Verdict | Evidence |
| --- | --- | --- |
| `lexicon { }` returns a Den aspect fragment with class keys | confirmed | `src/lexicon/default.nix:142-198` returns `homeManager` and/or `nixos` module functions |
| "the current behavior with include pass-through added" | confirmed | `bind` builds only those two keys; `includes` and `name` aren't passed through. Whether `includes` is rejected or ignored today wasn't evaluated (assumption: rejected as an unknown field) |
| Den calls the class functions with `host`/`user` | partly right | The module system calls them. Den pre-applies context args it finds in `builtins.functionArgs` (`D/nix/lib/aspects/fx/class-module.nix:106-118`), which works because the bridge declares `host ? null, user ? null` |
| Stages 3 to 8 run per slice | partly right | Static preparation runs once per `lexicon { }` value (`prepared = bound.prepare raw`, `src/lexicon/default.nix:113`) before any slice. The NixOS bridge compiles system `nixos` and user `resources` in the same invocation (`:177,186`) |
| Roster and principals come from `src/den.nix` | confirmed | `src/den.nix:167-211` |
| `mkTarget` and `hostAspects` reach Den internals | confirmed | `src/den.nix:81-125` |

## Plan settle order (P:254-262)

Partly right. Today's order in `src/lexicon/resources.nix:187-225`:

1. validate every plan (`:190`)
2. normalize theme plans (`:191-194`)
3. expand directories, consuming the normalized themes (`:195-215`)
4. files are file plans then directory files; links are expanded external-link plans (`:218-224`)

Then `src/lexicon/runtime.nix:29-41` lowers theme entries per principal and adds their files, and
the coordinator module builds the collision index host-wide (`src/furnish/runtime.nix:68-75`).
The only data dependency is theme before directory. File and link plans don't depend on
directories; their order is output concatenation order. The fourth step in `definitions.md:65-71`
runs after `compose`, per principal. So `after` lists reproduce one edge, not "the current
four-step order exactly". The Build Systems à la Carte framing (static dependencies, topological
order) holds.

## Performance points (P:805-829)

| # | Verdict | Evidence |
| --- | --- | --- |
| 1 Effects per declaration, quadratic if state grows | partly right | Each step deep-forces state (`NE/src/trampoline.nix:132`). Krisis's state is constant size: a thunk-carried cons cell, a count and a flag (`K/src/report.nix:285-309`). `validation.all` uses the same carrier (`K/src/validation.nix:155-203`). The quadratic case doesn't arise in Krisis; send count still matters |
| 2 Slice multiplication | confirmed as a question | Static preparation is shared per declaration value (`src/lexicon/default.nix:113`) |
| 3 Environment rebuilds | confirmed | `flake.nix:93-106`. skadi's `forDen { inherit den; }` passes no dependency, so it hits the shared environment. `lib.den` and `lib.furnishRuntime` each build a fresh dependency set |
| 4 Registry built once | unverifiable | Plausible from `flake.nix:113`; not measured |
| 5 Walk cost | partly right | `genericClosure` is breadth-first (evaluated), so it can't be the depth-first walker |
| 6-8 | unverifiable | Measurement items |
| 9 Growing attrsets and strings; `toml/render.nix` first | partly right | `src/toml/render.nix:29-32,57` already builds fragment lists joined once. Better first candidates: `src/praxis/graph.nix:62-70` (`stack ++ [ name ]` per visit), `src/ownerships/axes.nix:764,913` (`claim // ...` per descriptor, small k) |
| 10 Validation in loops | unverifiable | Not traced |

## Den behaviors (P:455-495)

| Claim | Verdict | Evidence |
| --- | --- | --- |
| Dedup by identity, name chain plus context id; unnamed never dedup | partly right | The key also includes the current scope: `dedupKey = "${scope}/${identity.key child}"` (`D/nix/lib/aspects/fx/handlers/check-dedup.nix:17-23`); identity is chain, name and `{ctxId}` (`D/nix/lib/aspects/fx/identity.nix:19-25`) |
| Depth-first pre-order | unverifiable | Not found in Den's docs or the files read |
| Unreachable kinds are silently inert | confirmed | `D/docs/src/content/docs/explanation/parametric.mdx:62-66`. The inert verdict at one scope can be delivered at another (`D/nix/lib/aspects/fx/handlers/inert.nix:4-9`), so a trace must record scope |
| Flat-form class modules | confirmed | `D/nix/lib/aspects/fx/class-module.nix:106-118` |
| Batteries as aspect values or functions | confirmed | used as `den.batteries.primary-user` and `(den.batteries.user-shell "fish")` in skadi |
| `den.default` as root include | confirmed | skadi `modules/den.nix:19-20` |
| Leave out `provides`, `_`, `meta.guard`, `hasAspect`, `__findFile` | confirmed as unused by skadi | grep above. Den also has `excludes`, `description`, `into`, `classes`, `policies` structural keys (`key-classification.nix:10-22`); the proposal doesn't say whether a plain aspect may carry `description` |
| Lexicon injects `host`/`user` into `homeManager` | confirmed | `src/lexicon/builtins.nix:145-146` (`lib.setFunctionArgs`) |

## The lead's review claims

1. **Record openness.** Right that `fx.types.Record` is closed and the README is stale; wrong that
   `RecordOpen` is usable, since it isn't exported. See the section above.
2. **`core.discovery.tree` violates "core never names a subsystem".** Right. P:92 forbids it and
   P:353 does it. It also puts filesystem discovery in core, which `definitions.md:20` forbids for
   definitions. Discovery's walk belongs in the discovery subsystem.
3. **`nixos` is ambiguous under one composition model.** Partly right. An author sees two meanings
   (`syntax.md:53` units list vs a native module in a Den aspect). The runtime only becomes ambiguous
   under the proposal's model, where the walker must classify `lexicon { }` values as an aspect kind
   (P:444-447) without a tag. If `lexicon { }` compiles to a class-keyed fragment in every host, as
   it does under Den today, the walker never sees Lexicon's `nixos` and the key has one meaning at
   the aspect level.
4. **Two walkers should be a dated limit.** Wrong in framing. The owner fixed Den as a host adapter
   and skadi as day-one working. Under Den, Den walks because batteries and quirks are Den
   features skadi uses (`modules/den.nix:16`, `users/*.nix`). A date means either dropping the Den
   host or running Lexicon's walker inside Den, which loses those. The right change is narrower:
   conformance covers only the portable aspect subset, and Lexicon's compile path is identical in
   both hosts because it lives in the class module functions.
5. **Nine works weren't fetched.** Fetched or resolved each one:

   | Work | Result | Action |
   | --- | --- | --- |
   | Plotkin and Pretnar, Handlers of Algebraic Effects | PDF fetched; title and authors on page 1 | keep |
   | Carette, Kiselyov, Shan, Finally Tagless, Partially Evaluated | PDF fetched; page 1 reads "Under consideration for publication in J. Functional Programming" | keep; it's the preprint |
   | Swierstra, Data types à la carte | given URL returns 404 | replace with DOI `10.1017/S0956796808006758` (Crossref: JFP 2008) |
   | Wadler, The Expression Problem | fetched; dated 12 November 1998 | keep |
   | Sarkar, Waddell, Dybvig, nanopass infrastructure | `legacy.cs.indiana.edu` doesn't resolve; `www.cs.indiana.edu` redirects to a department page | replace with DOI `10.1145/1016850.1016878` (Crossref: ICFP 2004) |
   | Knuth, Semantics of Context-Free Languages | DOI resolves to Springer behind a bot check | keep the DOI; Crossref confirms Mathematical Systems Theory 1968 |
   | Meijer, Fokkinga, Paterson, Bananas | PDF fetched; title and authors on page 1 | keep |
   | Shapiro et al., CRDTs | HAL page blocked by a bot check | replace with DOI `10.1007/978-3-642-24550-3_29` (Crossref: SSS, LNCS 2011) |
   | Yorgey, Monoids: Theme and Variations | host resets the connection | replace with DOI `10.1145/2364506.2364520` (Crossref: Haskell Symposium 2012) |

   Spot checks of the "confirmed by search" set: Keep and Dybvig `10.1145/2500365.2500618` and
   Mokhov et al. `10.1145/3236774` resolve in Crossref with matching titles.
6. **mergeDefinitions.** The assumption at P:429-434 is right in its main line and wrong in its
   conclusion. At `NP/lib/modules.nix`:
   - `mergeDefinitions` (`:1187`) first runs `dischargeProperties` on each definition (`:1190-1202`),
     which expands `mkMerge` and drops false `mkIf` (`:1377-1386`). Only the top level of each value
     is discharged; nested properties are pushed down earlier by `pushDownProperties` (`:1337-1356`)
     for attrset config.
   - `filterOverrides'` (`:1206`, `:1417-1440`) keeps only the definitions at the highest priority
     (numerically lowest) and strips the `mkOverride` wrapper.
   - `sortProperties` (`:1209-1214`, `:1451-1470`) orders by `mkOrder` priority (`mkBefore`,
     `mkAfter`) and strips that wrapper.
   - A single definition with no `_type` skips all of this (`:1222-1240`).
   - Only then does it type-check and call `type.merge loc defsFinal` (`:1255-1256`), or `merge.v2`
     (`:1248-1253,1284-1291`).

   So a type's merge never sees `mkDefault`/`mkForce`, and lower-priority definitions are gone
   before it runs. The proposal's fallback, "the option type has to detect the wrappers itself", is
   impossible. What the adapter can see is `options.<loc>.highestPrio` and
   `options.<loc>.definitionsWithLocations` (`:1150-1153`), with no custom type at all. Priority use
   is visible only when the winning priority isn't the default 100. Two further consequences:
   `mkBefore`/`mkAfter` reorder definitions, so module order isn't meaningless for an `append`
   leaf, and a leaf written `mkForce (mkIf c v)` reaches the merge with the raw `mkIf` record.

## Missed by both the proposal and the review

1. The collision index is host-wide and lives in the coordinator module (headline 1).
2. `lexicon.furnish.state` is service configuration, not a Lexicon setting (headline 2).
3. Moving `src/furnish/runtime.nix` under `systems/services` breaks layering (file table).
4. Failure would move from throws to assertions (headline 6).
5. The extension `fields` format changes with Axiom (headline 7).
6. No shared `fx` instance across public entry points (headline 8).
7. Lexicon paths are rendered labels, not Krisis structured paths; every diagnostic site changes.
8. Directory inventories read the filesystem at evaluation with `builtins.readDir`,
   `builtins.pathExists` and `builtins.readFileType` behind `builtins.tryEval`
   (`src/program/directories.nix:30,106-109`). That's pure for flake-source paths and
   import-from-derivation for a string source carrying derivation context; the schema accepts
   strings (`src/lexicon/resources.nix:62`). `syntax.md:121` says no existence lookup runs, which
   is false for directories. The `tryEval` conversion also contradicts AGENTS.md.
9. `restructure.md:76-77` says a block from a disabled subsystem fails as an unknown field; the
   proposal's law 6 (P:201-203) adds a reserved index and a different message. That changes an
   owner-approved page and needs a ruling.
10. `restructure.md:68` lists `services` as names; the proposal makes them records. Same ruling.
11. The proposal says Lexicon "trusts its input" between stages (P:222-223), but `lower` is
    extension code. The envelope check (P:233, `src/declarations/outputs.nix`) must stay, and it
    does in the proposal's table; the sentence overstates it.
12. Den's dedup key includes scope (Den behaviors table). A plain walker that drops scope from the
    key dedups across scopes where Den doesn't.

## Non-Nix components (owner directive: pure Nix at evaluation)

Rule applied: evaluation, including compilation, validation, rendering, settings, composition, docs
generation and retained tests, is Nix with no import-from-derivation. A non-Nix piece stays only
where execution happens outside evaluation and Nix can't do the job. Throwaway probes live in
scratch and aren't retained.

| Component | Runs | Verdict | Reason or owner |
| --- | --- | --- | --- |
| `src/praxis/runtime/` (Rust) | user time | keep | Interactive CLI, process execution, PTY and notification handling (`src/praxis/runtime/src/process.rs`, `ui.rs`) |
| `src/praxis/generic.nix:65-170` shell launcher | user time | keep | Locates the project and runs `nix eval`/`nix build` from the user's directory. Candidate to fold into the Rust runtime later; not evaluation work |
| `src/praxis/wrapper.nix:16` launcher | user time | keep | Same reason |
| `src/praxis/outputs.nix:69-77` check `runCommand` | build time | keep | Runs the user's command as a flake check; that's process execution |
| `src/toml/runtime.py` `publish` | activation and user time | keep | flock, atomic writes and reload hooks (`runtime.py:204-240`) |
| `src/toml/runtime.py` `merge` | build time | keep, bounded | Sources may be derivation outputs (reading them at evaluation is IFD) and the merge retains comments and formatting, which `builtins.fromTOML` loses. Restrict to file sources; Nix-valued sources merge in Nix |
| `src/toml/runtime.py` `validate` in `generate` (`src/toml/default.nix:30-36`) | build time | replace with Nix | The renderer is already Nix (`src/toml/render.nix`). A round trip through `builtins.fromTOML` at evaluation checks the output; Nix integers are already 64-bit. Owner: `systems/render/toml`. Parity needs the TOML spike |
| `src/program/theme/adapters/caelestia.nix:37` hook script | user time | keep | Caelestia invokes it at theme change |
| theme systemd units (`composition-runtime.nix:158-190`, `matugen-runtime.nix`) | activation | keep | Runtime publication |
| `tests/praxis/terminal.py` | test of the Rust runtime | keep | Drives a real PTY and foreground process group (`terminal.py:11-15`); Nix can't. Moving it into the Rust crate's own integration tests is an option, not required |
| `tests/toml/test.py`, `tests/toml/protocol.py` | test | split | Keep the parts that exercise `publish`/`merge` (locking, files, processes). Replace rendering and encoding assertions with nix-unit cases using `builtins.fromTOML` |
| `tests/system/harness/` (Go) | VM test | keep | Rebuilds and boots a VM and inspects a running system |
| `tests/system/program-files-regression.sh` | VM test | keep | Drives VM switch and reboot cases |
| `tests/system/furnish-coordinator-gate.sh` | gate | keep, review | Requires a clean git tree and runs VM gates. The devenv `gate` task may absorb its pure part |
| `verification/components/contracts.py`, `observe.py` | test driver | replace with Nix | They run `nix-instantiate` to assert errors and demand (`tests/declarations/observations-check.nix:30`). nix-unit expected-error cases and throwing-sentinel tests cover this (assumption: the pinned nix-unit supports error-message matching; the tooling worktree confirms) |
| `verification/components/profile-contracts.py`, `compare.py`, `snapshot.py`, `toml.py` | measurement | delete after the kernel audit | Measurement, not tests. Keep results in `verification/*.md` records; future probes stay in scratch |
| `examples/praxis-scripts/scripts/source.sh`, `tests/praxis/fixtures/*.sh` | fixtures | keep | Payloads a Praxis command runs, not helpers |
| directory inventory `builtins.readDir` (`src/program/directories.nix:30`) | evaluation | keep in Nix, constrain | Nix, but must reject sources with derivation context so it can't become IFD |

Test refinement from the owner: probes in other languages are scratch-only and never retained;
retained tests are nix-unit or Nix flake checks unless they drive a terminal, a VM or a running
process. Under that rule `terminal.py` (PTY), the Go harness and the VM shell scripts stay; the
TOML Python tests stay only for `publish` and `merge`; `contracts.py` and `observe.py` go.

## Benchmark material

Read for the benchmark suite ruling:

- `verification/components/README.md` documents a working comparison discipline: fixed sizes 4,
  16, 64; one warm-up and three alternating pairs; fixed noise bounds; `SIGKILL` timeouts; counting
  and profiling in separate processes; a record grammar qualified against CppNix 2.34.8 only.
  Ruling: keep the discipline, replace the Python. The schedule and grammar rules move into Nix
  analysis; the workloads (`workload.nix`, `fleet.nix`, `compiler.nix`, `resources.nix`,
  `praxis.nix`, `toml.nix`) become `bench/workloads/`.
- `verification/praxis-diagnostic-profile.md:1-14,177-215` shows Krisis envelope validation through
  the nix-effects type kernel dominating diagnostic cost (2,792 of 3,079 samples; 576 envelope
  builds for 128 diagnostics). Neither the proposal nor the review lists this as a Krisis
  requirement. It becomes contract item K9.
- `NE/bench/` is a model: a shell runner (`runner/run.nix`) with Nix finalizers, deterministic
  allocation counters from `NIX_SHOW_STATS` as the gate signal (`lib/measure.nix:1-10`), CPU time
  reported, a joint relative-plus-absolute tolerance (`budgets.toml`).
- Evaluators, checked by running them: host Lix 2.95.4 writes `NIX_SHOW_STATS` JSON and honors
  `NIX_COUNT_CALLS` (per-position `functions`), and rejects `eval-profiler` as an unknown setting.
  CppNix 2.34.8 lists `eval-profiler`, `eval-profiler-frequency` (default 99) and
  `eval-profile-file` in `nix config show` (checked with a 2.34.8 build already in the store).
- The flake's nixpkgs (`b7c2ada9`) has `nixVersions.nix_2_34` at 2.34.8, out path
  `/nix/store/g1k5iczz0l8i8d7kk5bk8rwv139g3l02-nix-2.34.8`, and `pkgs.nix` and `nixVersions.stable`
  are also 2.34.8 (evaluated). Attribute names `nix_2_4` through `nix_2_35` exist. The devenv shell's
  nixpkgs follows Lexicon's lock (worktree `devenv.yaml`), so its `nix` is `pkgs.nix`.

## Round-one review evidence

- Krisis tests are nix-unit suites registered in `tests/default.nix`: `baseline`, `boundaries`,
  `examples`, `extensions`, `integration`, `presentation`, `source` and `qualification.*`. Its
  toolchain is Nix and nix-unit 2.35.1 from `nix/toolchain.nix`, and `checks.tests` already runs
  nix-unit inside the build sandbox (`docs/development.md`). Krisis has no cost check today.
- Current diagnostic namespaces (`codePrefix` arguments): `lexicon`, `lexicon/resource`,
  `lexicon/unit`, `ownerships`, `ownerships/import`, `ownerships/merge`, `collision-detection`,
  `program`, `praxis`, `registry`, `toml`, plus literal `den/drop-no-match` and `lexicon/theme-id`.
  No consumer passes a Krisis policy, so `suppressCodes` lists don't pin these names.
- Per-call dependencies: `flake.nix:57` (`withDependencies`) calls `dependenciesFor` per factory
  call, and `src/dependencies.nix:8` applies the qualified source each time.
- Consumer-surface warts in skadi: four aspects use `{ includes } // lexicon { ... }`
  (`ai/claude-code`, `editors/nvim`, `gaming/prismlauncher`, `desktop/compositors/hyprland`);
  `outputs.nix:5,11,12` binds three Lexicon values; `system/impermanence.nix:1,23` imports
  `furnishRuntime` only for the option; ten `lib.toml { inherit pkgs; }` instantiations sit in six
  files. Eleven files use `nixos` units, three of them with ownership claims (`system/audio.nix`,
  `ai/claude-code`, `media/obs`), so the `value` wrapper carries meaning.
- Den batteries skadi uses: `define-user`, `primary-user`, `user-shell` (`users/*.nix`). Den's
  Home Manager battery forwards user content to `home-manager.users.<userName>`
  (`D/modules/aspects/batteries/home-manager.nix:12-16`).
