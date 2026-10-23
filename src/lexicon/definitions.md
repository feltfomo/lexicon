# Subsystem and annotation definitions

This contract governs `lib.lexicon.configure` and the built-in definitions. Consumer syntax is described in syntax.md.

## Construction

`lib.lexicon.configure { extensions = [ extension ]; }` compiles built-ins and extensions into one environment. It returns `forDen`, `forRoster`, `forTarget`, `withResolvers` and the configured `ownerships` API. Default factories delegate to `configure { extensions = []; }`.

An extension is a pure function receiving `{ lib, axiom, krisis, definitions }` and returning a closed record with required nonempty `name` and optional `blocks`, `ownership`, `relations`, and `metadata`. All four optional fields default to empty lists. The function receives definition constructors and existing library dependencies, not a partially constructed recursive registry.

- `blocks` contains block definitions.
- `ownership` contains Ownerships descriptors. Public definition helpers expose the existing set-descriptor constructor and default descriptor contract without requiring imports from Lexicon internals.
- `relations` contains Ownerships relation definitions.
- `metadata` contains `{ name, field }` registrations, where `field` is an Axiom schema field specification. They define `metadata.<name>` on declared record nodes.

Extension names identify registration errors. They aren't another namespace in aspect files. Block and author-key names are globally unique within one configured environment. Registering the same extension twice is an error. Built-in definitions register first; extensions follow their authored list order. Diagnostic order is stable and explicit. Record attribute names use Nix's sorted order where no authored list exists.

Axiom's registry compiler validates registrations before indexing them. Don't combine definitions using `//` or `listToAttrs` before duplicate checking; both can hide collisions. Validate extension records, block definitions, descriptor author keys, relation references and metadata fields. A metadata key may share a spelling with a top-level domain field because `metadata` is a separate namespace. A root ownership key may not collide with a block or structural field.

Definitions are trusted imported Nix code. Static registration and ordinary function application are enough. No filesystem discovery, dynamic plugin loader, parser, language evaluator or Nix module option system is introduced.

## Block definition

A block definition contains `name`, `scope`, `outputs`, `node`, and `lower`. `outputs` is a unique list of supported contribution names, `nixos`, `homeManager` and `resources`. Emitting an undeclared contribution kind is a definition error. `scope` is `user`, `system`, or `split`. User blocks compile per selected user; system blocks compile once per host; split blocks explicitly describe both projections. Direct binding preserves a host-only target for package/Home Manager-only declarations. A user-scoped native module output may therefore remain a deferred Home Manager module without a concrete user in direct mode. File-producing declarations still require a concrete user target, including their existing empty-callback cases. Definitions capable of resources may supply `resourceIntent = structure: bool`; it defaults to true for those definitions and false otherwise. This structural check cannot invoke callbacks or force sources. Built-in Furnish preserves its existing distinction between empty static collections and callbacks that might produce files; an empty callback result still requires a user. The compiler rejects nonempty resource output when intent was false. The intent contract controls target requirements, never ownership selection. The native system adapter is system-scoped; the common compiler projects enclosing declaration claims. External definitions should normally choose one scope.

`node` describes only the structural boundaries the common compiler must traverse. It uses the following forms supplied by the definition helpers:

| Node | Contract |
| --- | --- |
| Record | `fields` is an Axiom field-specification set; `children` maps child names to node descriptions. The compiler adds common annotations. An optional `prepare` callback belongs to this record node. Domain and child names cannot collide. |
| Collection | `item` describes each item; `contextual = true` is shorthand for a contextual wrapper around the collection. |
| Contextual | `definitions.contextual node` accepts static data or one context callback returning the same data shape. Its node must compile to a record, collection or record map. |
| Record map | Caller-chosen names map to records described by `item`; keys have an explicit validator and traversal uses sorted key order. |
| Value | One domain field specification, with no recursive traversal or annotation boundary. |
| Native | Opaque value with an immediate shape check and a named native owner; no recursive traversal. |
| Output projection | `definitions.forOutputs [ "resources" ] node` assigns a branch to a requested output bridge without adding an annotation boundary. |
| Recursive | `definitions.recursive (self: node)` binds an internal reference to a finite compiled node body. References expand only at authored occurrences. |

A record's domain schema validates selected payloads. Its structural vocabulary, annotation fields and immediate child container shapes are checked without inspecting selected domain values. This separation is required for a source field that throws on an inactive entry.

The definition constructors compose these descriptions using Axiom schemas. They don't implement a second generic runtime type library. There is no path-expression language, wildcard parser or arbitrary tree-search callback. Records, collections and record maps describe current file entries, nested directory overrides, themes and renderer records. Dynamic renderer names use record-map item traversal. Existing Ownerships units support arbitrary nested `children`; their node uses the explicit recursive binder. Validate its finite body once at registration, validate references without expanding targets, and resolve them through the same traversal operations only as authored nodes are visited. Reject an unproductive binder that returns only itself through projection or contextual wrappers. No arbitrary deferred schema callbacks, depth cap or second claim walker is needed.

Contextual wrappers add no annotation boundary. A callback is invoked once when compiling a selected context, after ancestor selection and output projection; its result re-enters the wrapped node at the original authored path. Returned claims constrain that result and its descendants. They cannot gate their own callback before it runs. Another function result fails without invocation. Native/value nodes and adjacent contextual wrappers are rejected at registration. Existing contextual collections use this same callback owner.

Every declared record node is an annotation boundary. Value and native nodes inherit the enclosing record's applicability. A subsystem cannot declare an opaque record and then ask the core to discover ownership fields inside it. Structural fields and native boundaries must be documented alongside the block.

Public module bridges request one output projection. The Home Manager bridge requests `homeManager`; the NixOS bridge requests system `nixos` and user `resources` separately. Block output declarations filter participation. A mixed-output block explicitly assigns contextual/native branches to their bridge with `forOutputs`. Its pure common fields and enclosing annotations remain shared. An ambiguous contextual branch serving both bridges is a registration error. Static vocabulary, direct and scope checks still traverse declared branches; selection/domain validation and callbacks skip unrequested branches. No implicit sharing of configuration values across module systems is introduced.

`lower` receives `{ value, context, metadata, origins, prepared }`. `context.output` identifies the requested projection; its `config` belongs to that bridge. Resource callbacks always receive NixOS configuration. Native Home Manager functions remain opaque until its module system invokes them. The selected value tree includes only requested projected branches. Returned contributions must match the requested output; another nonempty contribution is an error. `value` is the validated selected domain tree with ownership and metadata fields removed. Selection filters collection entries while preserving their original authored locations in `origins`. A selected optional child record that selects nothing is omitted; it must not receive a schema default that recreates it. A selected collection with no surviving entries remains an empty list. An inactive root block never calls `lower`.

`metadata` and `origins` mirror declared nodes and selected collection order. Origins are compiler-supplied structured paths into the authored declaration. A subsystem attaches the matching origin to each emitted contribution. The output validator checks path shape; extension tests verify correct attribution after filtering. Trusted Nix code can misattribute an origin, so this is a diagnostic contract rather than an unforgeable token. Collection expansion keeps the originating entry path and adds generated-name context.

Lowering returns a closed contribution record containing optional lists `nixos`, `homeManager`, and `resources`, each defaulting to empty. Native contributions carry a module plus origin. Resources carry typed plans plus origin, using canonical `source`/`destination` vocabulary for files, links and directories. A theme plan is `{ renderer; blockId; entry; }`, where entry contains effective theme fields. Its optional prepared.fieldOrigins maps effective field names to authored paths. A directory preparation contains inventory, reservedNames and optional selected ruleOrigins. Plan kinds are `file`, `external-link`, `directory`, and `theme`. An external-link plan accepts either an individual `{ source; destination; }` record or a group `{ source; names; destinations; }`. The shared link owner validates the selected form and indexed path lists before expanding destination roots then names. External subsystems may emit groups through this same owner. Final links preserve provenance. Group labels retain the original entry path and both expansion indexes and values, with authored label text as a prefix. Each kind has an owning schema and compiler. External subsystems can emit any supported kind through that same contract. Directory/theme plans retain the information needed for shared resource composition before final single-resource expansion. The common output adapter supplies host namespace, principal and managed root; extensions don't choose a different authority or bypass containment by returning raw manifests.

A system block may emit NixOS modules. A user block may emit Home Manager modules and user resources. Scope-incompatible output fails. Split definitions emit separately for each allowed projection and do not merge user-selected data into a system contribution. Lowering cannot introduce fresh ownership claims or recursively return another DSL block. New native concerns can emit native modules; new filesystem representations use Furnish's existing executor contract, not another publication backend.

All selected resource contributions from every subsystem enter the resource composition stage below and the same Furnish compilation and collision checks. Native contribution lists retain normal module merging, priorities and imports. The built-in `nixos` ownership-unit adapter preserves its existing selection and Ownerships merge semantics before emitting its resulting native contribution. That domain behavior is not generalized into a native module merger. Compatibility tests must cover conflicting scalar units and native priority definitions so the refactor changes neither silently.

## Preparation and resource composition

`prepare = { structure, origins }: preparedValue` belongs to a record-node definition and defaults to an empty record. `structure` is that structurally validated authored record and its children before ownership filtering, with domain fields still lazy. The compiler binds a prepared result as a lazy value once per static record occurrence. It must not force preparation merely to test selection or render a diagnostic. The `prepared` argument to `lower` mirrors the selected node tree and supplies each surviving record's shared prepared value. Records produced by a context callback get their own lazy preparation within that selected context. Static sibling records retain their original shared preparation. No whole-block re-preparation is needed when only one collection is dynamic.

Directory preparation retains each override's authored names, including inactive overrides, separately from the selected rule payloads. Per-directory inventories are indexed by original authored paths and remain lazy until that directory is selected. Static directory inventories are shared across user slices. A definition's preparation must not evaluate descendant callbacks or inactive sources to collect structural reservations. Structural names needed for reservations are an explicit exception to payload laziness and keep their existing validation semantics. An arbitrary extension's preparation isn't permission to deep-force its tree.

Resource composition is a fixed owning stage, not an extension dependency scheduler. It receives all selected typed resource plans for the current declaration/principal and uses this order:

1. Validate and normalize selected theme plans through the existing theme compiler.
2. Expand selected directory plans using their prepared inventories, complete reserved-name sets, selected override rules and the normalized selected theme sources. Retain the existing exclusion/override conflict checks.
3. Lower ordinary files, links and theme-retained inputs to final Furnish resources, preserving the principal and origin of every plan.
4. Hand selected theme plans to the existing theme composition/runtime adapters. The host output adapter assembles their NixOS runtime modules with user-owned entries still carrying their original principal. These are resource-backend outputs, not arbitrary system configuration emitted by a user block.

The theme block wraps its existing record node with `definitions.contextual`. It is user-scoped and emits theme plans through this public contribution path. It doesn't need permission to emit arbitrary NixOS modules. Other user subsystems may emit the same typed plans. Runtime modules and retained renderer state remain owned by the existing theme implementation. No plan is serialized merely to pass it between pure compiler stages.

Cross-subsystem final destination collisions are checked together. Directory/theme source exclusion retains the current within-declaration behavior; this refactor doesn't invent global sibling-declaration source suppression or a parent/child destination overlap engine.

## Ownership annotations

Ownership descriptor callbacks retain their existing engine contract. A descriptor defines its author keys, shapes, allowed scopes, parsing, axis construction, context interpretation and diagnostics. Relations validate registered axes and compatibility. The registry derives claim extraction, stripping, schema fields and direct-mode rejection from those definitions once.

For example, a registered `roles`/`exceptRoles` descriptor would make this legal on a user-scoped entry:

```nix
{
  names = [ "monitors-lumi.conf" ];
  hosts = [ "lumi" ];
  roles = [ "desktop" ];
}
```

`roles` is illustrative and isn't a new default selector. A definition must provide its roster semantics and the binding must provide context. An arbitrary informational tag doesn't acquire selection semantics automatically.

The configured Ownerships API builds standalone rosters with added descriptors. `forRoster` uses that roster and an optional `selectionContext = args: extraContext`. `forDen` uses Den's existing base roster plus optional `selectionRoster` and the same context callback. Extra roster fields and context fields cannot overwrite base fields. Context additions may name only registered non-base axis context keys. The bridge owns `host`, `user`, `pkgs`, `config`, `scope`, `output` and internal bridge helpers; custom axes and enrichment cannot replace them. Keep Ownerships context projection unchanged; registered axes already survive that projection and are visible inside `when`. Context callbacks receive scope plus the already-bound context, and are demanded only when their added axes need context. Reject undocumented keys when the callback result is demanded; Collection callbacks and selectors use the same allowed extra-axis context. Native Home Manager functions receive only bound host/user injection; other names remain native module arguments. System ownership predicates see user=null while system collection callbacks retain the selected user. Missing context fails through Ownerships rather than matching everything or selecting nothing silently.

This first version supports context for existing host/user slices. An extension doesn't create a new execution scope, enumerate extra machines or turn one user into several independent runtime principals. A genuinely new execution scope needs a separate adapter and lifecycle design.

Advanced `withResolvers` takes `{ resolvers, filePrincipals, hostUserNames }`. `resolvers` is a builder called with the configured Ownerships API and returns `{ resolve, resolveSystem, resolvePrepared }`. The factory retains its own descriptor vocabulary and projection; it never infers them from callback arguments or compares function-containing registries for equality. Supplied resolver behavior is trusted code, and the builder must use the supplied Ownerships contract. Tests exercise this route with a custom axis.

Direct mode binds a concrete target and doesn't select. It rejects all registered ownership annotations across the declared tree, including callback-produced entries. Informational metadata is allowed. Default host/user rejection is one instance of the registry rule.

## Required proof of extension

Maintain a small external-style fixture imported through `configure`, outside the built-in compiler. It adds a user block named `bookmarks`, a role descriptor, and a `metadata.tags` schema. Its block contains a collection of source/destination records and lowers to external links. This is enough to prove registration without inventing an application-specific production subsystem.

A mixed-output fixture must prove that a NixOS-config-dependent resource callback stays untouched during Home Manager evaluation, receives NixOS config during resource evaluation, and preserves native Home Manager arguments/imports.

The fixture must exercise the role annotation on both `bookmarks` and built-in Furnish entries, and host annotations on both. Check declaration, block and entry ancestry, explicit metadata handling, callback-returned nodes, empty collections, unsupported system scope, missing custom context and registry collisions. Direct binding must reject the custom claim. Keep host-only direct package/Home Manager output valid and its coordinator dependency lazy; reject file-producing declarations without a user even when their collection callback returns an empty list. A custom block and a built-in block targeting the same destination must hit the common Furnish collision diagnostic.

Inactive blocks and entries contain throwing callbacks and sources to detect premature forcing. Native payloads contain ownership-like names to detect accidental traversal. Test original authored indexes after filtering and expansion. A malformed definition fails before its lower callback can run.

Use Axiom validation results throughout staged composition and Krisis to report diagnostics. Callback exceptions keep their original exception with evaluation context. Never deep-force application payloads to print a registry error.
