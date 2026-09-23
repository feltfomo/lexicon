# the registry is data. a fourth output block is one entry in this list plus
# its own file, and the assembly that reads the registry names none of them
#
# TODO the registry is built through the factory the declaration layer
# exposes, parameterised by this subsystem's kinds and its own diagnostic
# namespace. a new output is one file beside these three and one entry in the
# list below, and nothing else changes. a second copy of the ordering, the
# legality question, the classification or the malformed registration checks
# is the thing this seam exists to prevent, so anything that looks like one
# belongs here as an argument instead
{
  lib,
  fx,
  krisis,
  kinds,
  factory,
  vocabulary,
}:
let
  arguments = {
    inherit lib fx;
    inherit (krisis) suggest;
    inherit (vocabulary.text) shown prose;
  };

  of = factory {
    inherit kinds;
    namespace = "telos";
  };

  declared = map (entry: import entry arguments) [
    ./checks.nix
    ./devShells.nix
    ./packages.nix
  ];
in
of declared
// {
  inherit of;
}
