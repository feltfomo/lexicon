{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  roster ? null,
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
  canonical = api.forRoster { inherit roster; };
  translate = import ../lexicon/legacy.nix {
    inherit lib krisis axiom;
    inherit (api.ownerships) claimKeys;
  } { };
in
builtins.seq canonical (spec: canonical (translate spec))
