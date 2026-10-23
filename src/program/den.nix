{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  den ? null,
}:
let
  api = import ../lexicon {
    inherit
      lib
      krisis
      axiom
      mkCoordinator
      ;
  };
  canonical = api.forDen { inherit den; };
  translate = import ../lexicon/legacy.nix {
    inherit lib krisis axiom;
    inherit (api.ownerships) claimKeys;
  } { };
in
builtins.seq canonical (spec: canonical (translate spec))
