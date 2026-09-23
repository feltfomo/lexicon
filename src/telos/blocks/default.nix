# the registry holds block declarations; assembly reads it without naming
# individual blocks.
#
# TODO build the registry through the declaration factory so ordering,
# legality, classification, and malformed-registration checks have one source.
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
    ./commands.nix
    ./devShells.nix
    ./fmt.nix
    ./packages.nix
  ];
in
of declared
// {
  inherit of;
}
