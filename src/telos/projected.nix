# data. where each output block's compiled half lands in the standard flake
# surface, and in which of the two shapes an output attribute takes. a block
# with an entry here is projected and reachable with no knowledge of lexicon,
# and a block with no entry is lexicon's own and only lexicon reads it
#
# omission is the exclusion mechanism. nix offers no way to narrow what it
# walks, so the only lever on whether an attribute is checked is whether the
# attribute exists, and that lever is this table
#
# the entries are built through the placement builders, and which shape an
# entry takes is answered against the declaration where a reader dispatches on
# it rather than here
{ placement }:
{
  checks = placement.byName "checks";
  devShells = placement.byName "devShells";
  packages = placement.byName "packages";
  fmt = placement.only "formatter";
}
