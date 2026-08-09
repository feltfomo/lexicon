{
  lib,
  krisis,
  axiom,
  descriptors ? null,
  relations ? null,
}:
let
  surface = import ./surface.nix {
    inherit
      lib
      krisis
      axiom
      descriptors
      relations
      ;
  };
  unitImporter = import ./import-units.nix { inherit lib krisis axiom; };
in
{
  inherit (surface)
    mkResolve
    mkResolveSystem
    mkResolveTrace
    mkResolveSystemTrace
    mkResolvePrepared
    mkResolveMatrix
    mkResolveSystemMatrix
    mkResolveStrict
    mkResolveSystemStrict
    mkResolveProfiled
    mkResolveSystemProfiled
    translate
    claimKeys
    define
    toRoster
    mkRoster
    ;
  inherit (unitImporter)
    importUnits
    importUnitSets
    ;
}
