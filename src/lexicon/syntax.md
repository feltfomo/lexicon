# Declaration syntax

This contract governs canonical declarations and extensions.

## Vocabulary

| Term | Meaning |
| --- | --- |
| Declaration | The complete value passed to `lexicon { ... }` |
| Block | A named section with an owning definition, such as `furnish` or `theme` |
| Entry | One record in a collection, such as a link or directory override |
| Annotation | A registered field with common semantics at an eligible declaration, block or entry |
| Subsystem | The implementation that supplies block definitions and their compilation |
| Definition | The registration that describes vocabulary, shapes, boundaries and behavior |
| Native payload | A value interpreted by another owner, such as a Home Manager module |

These terms don't introduce a Nix module system. Declarations are ordinary Nix values. Nix parses and evaluates them; Lexicon validates registered vocabulary, applies annotations and compiles selected values.

`hosts = [ "khion" ];` is an ownership annotation. The annotation name is `hosts`; `khion` is a host selector value. Annotation definitions say what a field means. A random field does not become an annotation merely because its value is a list.

## Consumer syntax

```nix
{ lexicon, ... }:
{
  den.aspects.skills = lexicon {
    furnish.links = [
      {
        source = "/home/feltfomo/Projects/skills";
        names = [
          "subphase-architect"
          "subphase-implementer"
          "subphase-orchestrator"
        ];
        destinations = [
          ".claude/skills"
          ".codex/skills"
          ".agents/skills"
        ];
      }
    ];
  };
}
```

Registration belongs at factory construction, outside aspect files. The injected `lexicon` is a plain function. Small declarations stay small; consumers don't repeat schemas, registration records, type tags or output adapters.

| Built-in field | Accepted value | Owner |
| --- | --- | --- |
| `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when` | Registered ownership annotations | Ownerships |
| `metadata` | Record of explicitly registered informational annotations | Annotation compiler |
| `package` | `pkgs: derivation` | Package adapter |
| `nixos` | Ownership-unit list or context function returning that list | System adapter and NixOS |
| `homeManager` | Native module record or module function | Home Manager adapter |
| `furnish` | Annotated block containing optional resource collections | Furnish subsystem |
| `theme` | Annotated theme record or context function returning that record | Theme subsystem |

`package` and native `homeManager` are specialized fields, not additional annotation-bearing record containers. Their enclosing declaration supplies shared annotations. Built-in convenience fields use the same registration and output contracts as external definitions.

## Annotation rules

Ownership annotations use Ownerships descriptors. A descriptor defines accepted author keys, value validation, permitted scopes, context interpretation and claim composition. Relations describe compatibility between axes. Subsystems may contribute descriptors and relations to the common registry. Their additions apply across all eligible blocks, including blocks supplied by other subsystems.

All declaration records and registered Lexicon record nodes accept the registry's ownership vocabulary. This includes `furnish`, resource entries, directory override entries, theme templates and renderer records. Definitions describe their child record boundaries. A subsystem cannot silently opt out of shared ownership processing. A record that cannot support an axis reports an unsupported-scope diagnostic.

Ancestor claims constrain descendants. A child may narrow applicability but cannot widen an ancestor. Existing include/exclude and predicate semantics remain Ownerships' responsibility. System compilation projects enclosing user claims as the existing declaration adapter does; explicitly user-scoped annotations on system ownership units remain errors. New descriptors must specify their projection and scope behavior through that same contract.

Informational annotations live under `metadata`, with registered keys such as `metadata.tags`. They don't select a target, change authority or modify resources. They are local to the authored node and don't inherit implicitly. They are available to the owning subsystem as validated metadata. Metadata fields require explicit schemas; this is not an unchecked catch-all.

`label`, `provenance` and existing policy fields retain their domain meanings. They aren't silently renamed or promoted into metadata. Registering a colliding annotation name fails.

Native payloads are opaque to this vocabulary. `homeManager.users`, NixOS `value.users`, application configuration and renderer `native` records are interpreted by their owners. Annotation discovery never recursively scans arbitrary attribute sets. An annotation inside an opaque native payload has no Lexicon meaning.

A scalar or function field gains applicability from its nearest declared record ancestor. To give part of a native module separate ownership, use a declared ownership unit or another Lexicon declaration. Don't wrap every native option in a new DSL.

## Registration and extension

The factory compiles definitions once. See definitions.md for the extension contract and example. Unknown fields at Lexicon-owned nodes fail against the resulting vocabulary. A registered custom selector is recognized by built-in blocks and custom blocks alike.

Definitions must describe each record boundary, child collection, callback boundary, native payload and compilation scope. They supply domain schemas and lowering functions. The common compiler adds annotation fields and performs ownership processing. Definitions don't hand-roll selector filtering.

Default built-ins are ordinary registered definitions. Extension registration adds definitions; it doesn't override built-ins. Duplicate block names, annotation author keys, relation names, metadata keys and reserved structural names fail before declaration compilation. Definitions are trusted Nix code, not sandboxed plugins.

Public bindings remain `lib.lexicon.forDen { den }`, `.forRoster { roster }`, `.forTarget { target }` and advanced `.withResolvers`. `lib.lexicon.configure { extensions = [ ... ]; }` returns those same factories plus an Ownerships API using the configured descriptors. Each configured factory carries the same compiled definitions. Default factories are the empty-extension configuration.

Roster and Den bindings may accept `selectionContext = args: extraContext` for added axes. Den additionally accepts `selectionRoster = { ... }` for extra roster data. Additions cannot overwrite the built-in host/user context or roster fields. Missing context for a selected custom axis fails clearly. `forRoster` accepts the already-extended roster built through the configured Ownerships API. Advanced resolver binding supplies a builder receiving the configured Ownerships API, as specified in definitions.md. The factory retains the vocabulary and projection instead of accepting another claim list.

`forTarget` retains direct-mode semantics. It rejects every registered ownership annotation at every declared node, including callback results. Informational metadata remains valid. It must not keep a private hardcoded claim list. Host-only direct targets remain valid for package/Home Manager-only declarations; file-producing declarations require a user target, including empty collection callbacks.

## Evaluation and validation

Use Axiom's `src/schema.nix`, `src/registry.nix` and `src/validation.nix` through the injected Axiom API. Use its runtime types when nested data needs them. Use Krisis diagnostic factories, reporters, structured paths and contextual evaluation. Axiom's `language/` is excluded. These dependencies already exist; this refactor doesn't require new libraries.

1. Compile and validate registrations. Freeze the vocabulary and deterministic order. Reject malformed definitions and collisions before creating lookup maps.
2. Check the declaration record and immediate known field/container shapes. Validate annotation shapes at reachable declared nodes. Don't force native bodies or resource sources to discover vocabulary.
3. Apply ancestor ownership selection before invoking a descendant callback or reading its payload. Callback outputs re-enter the same declared-node traversal and validation.
4. Validate selected domain payloads with their owning schemas. Expand valid collections, retaining authored paths and annotation ancestry. Accumulate independent diagnostics; stop dependent work after an invalid parent.
5. Run subsystem lowering only for selected values, supplying the lazy preparation defined in definitions.md. Validate its output envelope and enforce the selected scope and principal.
6. Compose selected theme and directory plans in the fixed resource stage, then send native modules to their module systems and final filesystem contributions through the shared Furnish compiler. Keep cross-subsystem destination collision checks and lifecycle behavior centralized.

Static directory preparation is a specific retained contract. The existing directory compiler separates a shared inventory from selection-dependent expansion, and inactive override names remain reserved. Preserve that behavior and its forcing boundaries while moving it behind a definition. Don't make arbitrary extension payloads eager under the name of preparation. Context-produced directories prepare only within their selected slice.

A registered context callback receives the existing `{ pkgs, config, host, user }` values plus explicitly configured selection context. Resource callbacks run in the NixOS resource bridge. Definitions with multiple outputs explicitly project contextual branches; Home Manager evaluation must never invoke a resource callback with Home Manager config. See definitions.md for branch projection and `context.output`. Static collections remain lists; static themes remain records. Record fields such as `source` remain data. Only registered callback boundaries invoke functions; no recursive function discovery. A whole `furnish` callback is outside this scope.

Errors name the authored location, such as `furnish.links[0].source`. Expanded outputs retain their origin. Krisis adds context to callback failures without replacing the original exception. No deep forcing, arbitrary payload serialization or `tryEval` conversion merely to improve a message.

This compilation is pure Nix. Checkout creation, filesystem reconciliation and runtime theme publication stay in their existing runtime owners. External target existence isn't a declaration input. Pipe operators are allowed under the existing evaluator feature configuration; they don't change validation or laziness semantics.

## Resource records

A managed file uses `source` and `destination`, with the existing optional `representation`, `onConflict`, `label`, `provenance` and ownership claims.

A managed directory uses `source`, `destination`, optional `exclude`, existing lifecycle fields, and `files` rules. A `files` rule retains its existing `names`, lifecycle and ownership vocabulary. Reserved names remain omitted from default expansion even when their rule is inactive. Theme sources inside a directory remain excluded from ordinary directory output through the existing theme integration.

An individual external link uses `source` and `destination`. Its source is the literal target path, including when it names a directory. It accepts existing link metadata and ownership claims; file-copy lifecycle policies do not apply.

A grouped external link uses `source`, `names` and `destinations`. Each destination root receives every named source, in destination-list then name-list order. The example above produces nine links. Adding a fourth destination produces twelve. Both forms accept `label`, `provenance` and registered annotations. A group cannot also contain `destination`; both lists are required.

`source` is a normalized absolute plain string. Names are normalized relative paths and may contain nested components. Destination roots are normalized home-relative or absolute paths. Empty components, `.` and `..`, contextual strings, duplicate names and duplicate roots are errors at their authored indexes. An empty names or destinations list emits no links, but all selected fields still validate. Furnish checks final destinations against the bound managed root and detects collisions with every other subsystem. Group-generated default labels retain the authored entry and both expansion indexes; authored label text prefixes that context and provenance is preserved.

Managed files and directories use individual records. No source-directory discovery or existence lookup runs during evaluation. The checkout may be absent until the native bootstrap service runs. The complete skills example in `examples/program-skills/skills.nix` keeps that service and packaged directory placement explicit.

## Native module boundaries

`homeManager` retains native `imports`, `options`, `config`, `_module`, and ordinary module arguments. Bound host/user injection applies to the declared function; nested imports receive ordinary module arguments.

`nixos` retains system ownership units. Native module content belongs under each unit's `value`, keeping ownership `users` distinct from native `users.users`. Canonical syntax accepts a list or registered context callback returning a list. A system unit cannot select users. The built-in unit adapter preserves its current Ownerships selection/merge before emitting a native module contribution; ordinary native contribution lists keep native module merging.

Theme accepts a static record or a context function returning that same record. The function receives the selected resource context, including NixOS `config`, `pkgs`, `host`, `user` and configured selection axes. Ancestor selection and output projection happen before invocation. Returned annotations then constrain the theme and its descendants; they cannot prevent the callback invocation that produces them. Returning another function is an error. A callback requires a concrete user target even when it returns an empty theme.

Theme remains top-level because it owns renderer behavior and runtime publication. It emits user-owned theme plans through the shared resource contract; the resource backend assembles retained resources and host runtime modules without changing their principal. Bootstrap services stay native. A declaration needn't install a package to publish files.

## Adding a feature

A new feature supplies or extends the component that owns its behavior. Define the consumer syntax and schema, eligible annotation nodes, context and scope requirements, selection timing, lowering outputs and failure cases together. New path fields use full words. Collections use lists of records; registered context functions return that same shape.

An external example and regression fixtures must demonstrate the extension through the public configured factory. Test a custom selector on a built-in block and an external block, ancestor narrowing, missing context, unsupported scope and inactive throwing payloads. A feature isn't extensible merely because its internal helper accepts another argument.

Changes to the DSL must update this contract, definitions.md, the owning schema and its public factory tests together.

## Compatibility

Keep a thin legacy `program*` adapter only for migration. It translates old flat filesystem fields, `pkg`, `src`, `dest`, `target`, top-level Home Manager imports and callback results into this vocabulary. It must preserve nested directory rules and native module semantics. Reject ambiguous mixing of old and new spellings in the same declaration.

Every adapter lowers to one canonical compiler. Retained manifests, executor tuples, runtime state paths and ledger identities do not change merely because public names change. Any later removal of compatibility exports is a separately reviewed API change.
