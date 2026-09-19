# lexicon.lib.registry: the one place a configuration says which hosts and
# users exist. every other subsystem asks this table instead of carrying its
# own fleet declaration.
args@{
  lib,
  axiom,
  krisis,
  ...
}:
let
  fields = import ./registry/fields.nix { inherit lib axiom krisis; };
  schema = import ./registry/schema.nix {
    inherit
      lib
      axiom
      krisis
      fields
      ;
  };
  core = import ./registry/core.nix {
    inherit
      lib
      axiom
      krisis
      fields
      schema
      ;
  };
in
core.make (
  schema.declaration (
    removeAttrs args [
      "lib"
      "axiom"
      "krisis"
    ]
  )
)
