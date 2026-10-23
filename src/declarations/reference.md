# Declaration compiler internals

This component owns definition registration, declared-node traversal and selected
contribution validation. Public Lexicon factories bind it through `src/lexicon`. Resource owners materialize
selected contributions through the shared composition stage.

Import it with `{ lib, axiom, krisis }`. `definitions` provides `record`,
`collection`, `contextual`, `recordMap`, `value`, `native`, `recursive`, `forOutputs`, `mkSetDescriptor` and
`mkPredicateDescriptor`. `configure { extensions = []; blocks = []; }` validates
registrations and returns the compiled `blocks`, configured `ownerships` and
`bind` function. `blocks` supplies built-ins; extensions are ordinary imported
functions receiving `{ lib, axiom, krisis, definitions }`.

An extension returns `name` and optional lists `blocks`, `ownership`, `relations`
and `metadata`. Metadata registrations are `{ name, field }`, with an Axiom field
specification. Descriptor and relation contracts are Ownerships' contracts.
Registration errors precede declaration traversal and lowering.

A block defines `name`, `scope`, `outputs`, `node`, `lower` and an optional
`resourceIntent`. Scope is `user`, `system` or `split`; output kinds are `nixos`,
`homeManager` and `resources`. Resource intent receives the authored structure and
must return a boolean without invoking callbacks or reading sources. Its default
is whether the block declares resource output.

Node constructors accept these arguments:

| Constructor | Arguments |
| --- | --- |
| `record` | Optional Axiom `fields`, node-valued `children`, and `prepare` function |
| `collection` | Required `item`; optional `contextual = true` permits callbacks |
| `contextual` | One record, collection or record-map node; permits one callback returning its data shape |
| `recordMap` | Required `item` and `key = name: bool` |
| `value` | One Axiom field specification |
| `native` | Required diagnostic `owner` and shallow `validate` predicate |

Records accept common ownership fields and registered metadata. Child containers
and annotation shapes validate structurally; domain schemas run only on selected
records. Native and value nodes don't introduce annotation boundaries. Native
payloads remain opaque after their immediate shape check.

`bind { roster = ...; }` binds configured Ownerships. The advanced alternative
accepts `resolvers = { resolvePrepared; resolveSystem; }`; callers must construct
these against the environment's configured Ownerships API. `direct = true`
selects every declaration and rejects registered ownership keys. This internal
binding takes already-constructed context; public adapters own context enrichment.

The bound `prepare declaration` returns `{ compile, validate, structure }`.
`validate` returns an Axiom result; `compile` finishes it through the shared native
Krisis bridge. `src/dependencies.nix` supplies the compatible extension view and
native instance. The reporting boundary retains Axiom's field interpreter and
converts its result into a computation yielding `Valid` or `Invalid`. Invalid
results have no value. Successful values cross effect boundaries in public thunk
carriers. Invoke
`compile { scope = "user"; context = ...; }` repeatedly for the same declaration.
Static record preparation and prepared Ownerships selectors are retained across
contexts. Records and collections produced by callbacks prepare within their selected context.
Independent validation failures accumulate in declared order before lowering.
Contextual wrappers add no annotation boundary. Their callbacks run after ancestor
selection and output projection, then validate the returned data at the same path.
Returned claims narrow descendants; a returned function fails without invocation.
Legacy contextual collections normalize to this owner.

Static scope prohibitions run before selection; callback-produced records receive
the same check after their callback runs. Callbacks and lowering receive context with its compilation `scope` supplied by
the compiler. Ownership predicates retain Ownerships' registered-axis context.

A record's `prepare { structure, origins }` result remains lazy until lowering
uses it. `structure` retains inactive children so directory rules can reserve
names without reading inactive source payloads. An extension must guard callback
collections when inspecting structure. Each static authored record has one shared
preparation thunk, including when a sibling collection is contextual.

`lower { value, context, metadata, origins, prepared }` receives selected domain
values with common annotation fields removed. For records, the accompanying trees
use `{ self, children }`: `origins.self` is the structured authored path,
`metadata.self` is local validated metadata, and `prepared.self` is record-local
preparation. Collections are lists and record maps retain selected keys. Value and
native nodes carry their path directly as origins and empty metadata/preparation.
Original collection indexes survive filtering. An inactive optional record is
omitted; an empty selected collection remains present.

Lowering returns optional lists `nixos`, `homeManager` and `resources`. Native
contributions are `{ module, origin }`. Resources are
`{ kind, value, origin, prepared? }`; supported kinds are `file`, `external-link`,
`directory` and `theme`. The output validator checks the envelope, scope, declared
outputs, origin paths and structural resource intent. Resource owners validate
payloads and compose plans before Furnish. `prepared` carries a directory's shared
inventory when its owner needs it. Origins are diagnostic provenance supplied by
trusted Nix code, not authority tokens.

User scope accepts Home Manager and resource contributions; system scope accepts
NixOS contributions. Resource-producing user declarations require a concrete user,
including callbacks returning no entries. Host-only direct native declarations
remain valid. Declaration ownership is projected into system scope; ordinary
nested records retain Ownerships' unsupported-axis errors. Split block roots also
project their enclosing annotations, while their children keep normal scope rules.

`tests/declarations/fixtures/bookmarks.nix` is an imported extension example. The
`declarations` flake check covers selection, callback boundaries, direct mode,
origins, preparation and malformed registrations. Public factory and resource
composition integration are covered by public.nix. See ../lexicon/definitions.md
for recursive definitions and native bridge output projection.
