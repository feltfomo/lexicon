# output blocks map to standard flake attributes through these placement
# shapes. omission keeps an attribute out of validation.
{ placement }:
{
  checks = placement.byName "checks";

  # a declared command lands under the attribute nix run reads, and lexicon's
  # own copy of it is what the binary discovers from
  commands = placement.byName "apps";
  devShells = placement.byName "devShells";
  packages = placement.byName "packages";
  fmt = placement.only "formatter";
}
