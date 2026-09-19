{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  roster,
  filePrincipals,
  hostUserNames,
}:
let
  ownerships = import ../ownerships { inherit lib krisis axiom; };
  resolvers = ownerships.mkResolvers roster;
in
import ../program.nix {
  inherit
    lib
    krisis
    axiom
    mkCoordinator
    filePrincipals
    hostUserNames
    ;
  inherit (resolvers) resolve;
  inherit (resolvers) resolveSystem;
  resolvePrepared = resolvers.prepared;
}
