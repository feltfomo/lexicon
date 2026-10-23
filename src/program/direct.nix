{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  target ? null,
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
  canonical = api.forTarget { inherit target; };
  translate = import ../lexicon/legacy.nix {
    inherit lib krisis axiom;
    inherit (api.ownerships) claimKeys;
  } { direct = true; };
in
builtins.seq canonical (spec: canonical (translate spec))
