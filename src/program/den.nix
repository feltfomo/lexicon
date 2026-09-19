{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  den ? null,
}:
let
  denApi = import ../den.nix {
    inherit
      den
      lib
      krisis
      axiom
      ;
  };
  inherit (denApi) roster;
in
builtins.seq roster (
  import ./bind-ownerships.nix {
    inherit
      lib
      krisis
      axiom
      mkCoordinator
      roster
      ;
    inherit (denApi) filePrincipals hostUserNames;
  }
)
