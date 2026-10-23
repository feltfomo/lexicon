{
  lib,
  axiom,
  krisisSource,
  krisis ? null,
}:
let
  fx = import krisisSource.lib.qualifiedNixEffectsSource { inherit lib; };
  native = krisisSource.lib.krisis { inherit lib fx; };
  bridge = import ./effects.nix { inherit axiom fx native; };
  effects = bridge // {
    reporter =
      if krisis != null && krisis ? mkReporter then krisis.mkReporter else diagnostics.mkReporter;
  };
  diagnostics = import ./diagnostic-compatibility.nix {
    inherit lib;
    effects = bridge;
    inherit (axiom) validation schema canonical;
  };
  types = import ./type-compatibility.nix {
    inherit lib;
    inherit (axiom) validation;
    inherit (diagnostics) mkDiagnostic;
  };
  inspection = import ./inspection-compatibility.nix {
    inherit lib;
    inherit (axiom) identity validation schema;
  };
  compatibility =
    diagnostics
    // types
    // inspection
    // {
      editDistance = lib.strings.levenshtein;
      suggest = native.suggest.nearest { };
      suggestWith = native.suggest.nearest;
    };
in
{
  inherit lib axiom;
  krisis = compatibility // (if krisis == null then { } else krisis) // { inherit effects; };
}
