# TOML

`lexicon.lib.toml { inherit pkgs; }` returns `generate`, `merge`, `source`,
`literal`, `document`, `inline`, `tables`, and the `package` containing
`lexicon-toml`. `lib` defaults to `pkgs.lib`. Build-time generation and runtime
publication use the same TOML Kit implementation from the caller's nixpkgs.
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
Null, functions and unsupported values fail with the offending key path.
Generated attribute keys follow Nix's sorted attribute order.

`inline attrs` forces an inline table. Nested `tables` constructors inside an
inline table become arrays of inline tables, as required by TOML syntax. `tables list` forces an array of tables,
including an empty one. Since TOML cannot distinguish an empty array of tables
from an empty array in text, an empty `tables []` renders as `[]`.

`literal text` parses exactly one TOML value. Use it for offset or local
datetimes, dates, times, `inf`, `-inf`, `nan`, `-0.0`, multiline or literal
strings, and a chosen numeric spelling. Additional assignments are rejected.
Nix normalizes its own `-0.0` to positive zero, so use `literal "-0.0"` when the
sign matters. Constructors are validated and don't reserve application keys.

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
