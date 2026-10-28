# the observation fixtures, built once from the inputs the nix-unit tree gets.
# nix-unit reads each fixture's tests, and the events flake check evaluates its
# cells one process at a time to read what the callbacks printed
{
  lib,
  pkgs,
  axiom,
  krisis,
  krisisSource,
  lexicon,
}:
let
  core = { inherit lib axiom krisis; };
in
{
  # the fixture swaps in a tracing axiom, so the factory builds its dependencies
  # from whichever axiom and krisis the caller passes
  ownerships = import ../ownerships/observations.nix {
    inherit lib axiom;
    ownerships =
      args:
      import ../../src/ownerships (
        (import ../../src/dependencies.nix {
          inherit lib krisisSource;
          axiom = args.axiom or axiom;
          krisis = args.krisis or null;
        })
        // builtins.intersectAttrs {
          descriptors = null;
          relations = null;
        } args
      );
  };
  compiler = import ../declarations/observations.nix {
    inherit lib axiom;
    compiler = import ../../src/declarations core;
  };
  resources = import ../furnish/observations.nix (core // { inherit pkgs lexicon; });
  terminals = import ../furnish/terminals.nix {
    inherit
      lib
      axiom
      lexicon
      krisisSource
      ;
  };
  praxis = import ../praxis/effects.nix (core // { inherit krisisSource; });
  effects = import ../effects-contract.nix (core // { inherit lexicon; });
}
