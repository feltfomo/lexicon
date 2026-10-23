{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  resolve,
  resolveSystem,
  resolvePrepared,
  filePrincipals,
  hostUserNames,
}:
let
  api = import ./lexicon {
    inherit
      lib
      krisis
      axiom
      mkCoordinator
      ;
  };
  canonical = api.withResolvers {
    resolvers = _: { inherit resolve resolveSystem resolvePrepared; };
    inherit filePrincipals hostUserNames;
  };
  translate = import ./lexicon/legacy.nix {
    inherit lib krisis axiom;
    inherit (api.ownerships) claimKeys;
  } { };
in
spec: canonical (translate spec)
