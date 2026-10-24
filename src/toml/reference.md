# TOML

`lexicon.lib.toml { inherit pkgs; }` returns `generate`, `merge`, `source`,
`literal`, `document`, `inline`, `tables`, and the `package` containing
`lexicon-toml`. `lib` defaults to `pkgs.lib`. Generated values are rendered by
one pure Nix renderer. TOML Kit from the caller's nixpkgs owns build-time
validation, retained-syntax merge and parsing for runtime publication.
The builder requires TOML Kit 0.15.0 or newer for TOML 1.1 and rejects older
versions. Lexicon's pinned version is 0.15.0.

```nix
let
  toml = inputs.lexicon.lib.toml { inherit pkgs; };
in toml.generate "settings.toml" {
  enabled = true;
  "key.with.dots" = "one key";
  server = { address = "localhost"; ports = [ 8000 8001 ]; };
  expires = toml.literal "2026-10-22T12:30:00Z";
  hosts = toml.tables [ { name = "first"; } ];
}
```

`generate name attrs` returns a file derivation. Attribute sets become tables;
nonempty lists of attribute sets become arrays of tables. Other lists become
arrays, with nested attribute sets rendered as inline tables. Empty lists stay
empty arrays. Nested and heterogeneous arrays are supported. Empty and quoted
keys, empty tables, and arbitrarily nested tables are supported. Strings,
booleans, signed 64-bit integers and finite Nix floats retain their types.
Paths and derivations become strings and retain their Nix store context.
Null, functions and unsupported values fail with the offending key path. Nix
validation accumulates independent errors through the shared native Krisis/Fx
owner. Constructor field schemas retain Axiom's checked-result boundary.
Diagnostics keep their original paths and injected reporter behavior.
Generated attribute keys follow Nix's sorted attribute order.

`inline attrs` forces an inline table. Nested `tables` constructors inside an
inline table become arrays of inline tables, as required by TOML syntax. `tables list` forces an array of tables,
including an empty one. Since TOML cannot distinguish an empty array of tables
from an empty array in text, an empty `tables []` renders as `[]`.

`literal text` supplies exactly one TOML value for build-time validation. Use it for offset or local
datetimes, dates, times, `inf`, `-inf`, `nan`, `-0.0`, multiline or literal
strings, and a chosen numeric spelling. Additional assignments are rejected.
Nix normalizes its authored `-0.0` to positive zero, so use `literal "-0.0"` when the
sign matters. Constructors are validated and don't reserve application keys.
Their function-valued `__lexiconToml` marker distinguishes them from ordinary
attribute sets. A string or other data at that key remains application data.
Constructor records reject unknown fields, missing or unknown kinds, and invalid
payloads. `inline` and `tables` require plain attribute sets for their tables;
derivations and other constructors aren't tables.

`document text` supplies a parsed whole document. It is rejected inside a value;
use attributes or an inline table for nested content. `source name value` converts
an attribute set or document to a file, and passes a path or file derivation
through. Use a document or file when comments, spelling or table ordering
matter. Document text is parsed as TOML. Its values never pass through a JSON value
conversion, even when the text travels in the builder's JSON input envelope.

```nix
toml.merge "merged.toml" {
  sources = [ ./defaults.toml (toml.document "# local\nlimit = 12\n") ];
  conflict = "last";
  arrays = "replace";
}
```

The sources list must be nonempty. Sources are processed in order. Tables merge recursively. Arrays and arrays of
tables are atomic values; they never concatenate or merge by index. `conflict`
is `"error"` by default and rejects any repeated leaf. `"first"` retains the
earlier value, and `"last"` replaces it, including table-versus-scalar conflicts.
`arrays = "replace"` is the only supported array strategy; it describes the
atomic operation when a conflict policy selects replacement. Comments and
concrete syntax on retained values survive. Incoming standalone comments also
survive, though their position can move when tables coalesce. Merging isn't a
byte-for-byte concatenation. The complete result is parsed again before use.
No import-from-derivation or mutable home-directory reads occur at evaluation.

The library renders directly during evaluation and returns a file derivation.
Its builder validates each original literal independently before validating the
complete document. Constructor shape, payload type and document placement errors
fail during evaluation. Raw literal/document syntax and range errors fail during
the build. Generated file sources stay opaque during evaluation.

The installed `lexicon-toml generate INPUT OUTPUT` command accepts the typed JSON
encoding and calls the same packaged Nix renderer using the consuming package
set's evaluator. The fixed expression reads JSON as data and uses the dummy store;
it needs no daemon, writable store, channel, registry or network. Python preserves
JSON numeric precision and nonfinite values at ingress, validates the result and
writes OUTPUT only after success. An existing output survives rendering or
validation failure. HOME is inherited unchanged.

CLI generation adds the evaluator to the package closure and starts one evaluator
process per invocation. Library generation starts no child evaluator. The `merge`
and `publish` commands start no evaluator. Their parser, retained-syntax
serialization and publication operations remain native.

Inline containers can use TOML 1.1 multiline syntax. Raw literal spelling is
retained, with a newline before following punctuation so a trailing comment
cannot consume a comma or closing delimiter. Generated whitespace is not a
byte-for-byte compatibility contract. Supplied document text is byte-preserved
by generation; retained merge syntax follows the merge contract above.
