{
  lib,
  pkgs,
  axiom,
  krisis,
  lexicon,
  retainedPath ? builtins.toFile "furnish-effects-source" "retained",
}:
let
  resource = import ../declarations/resource-effects.nix {
    inherit
      lib
      pkgs
      axiom
      krisis
      lexicon
      ;
  };
  furnish = import ./effects.nix {
    inherit
      lib
      axiom
      krisis
      retainedPath
      ;
    furnish = lexicon.lib.furnish {
      resolve = throw "unexpected observation resolver";
      resolveSystem = throw "unexpected observation resolver";
    };
  };
in
{
  inventory = resource.probe;
  materialization = furnish.callbackProbe;
  # the poison cell times the opaque-payload cases themselves, so it evaluates them directly
  poison = builtins.all (case: case.expr == case.expected) (
    builtins.attrValues resource.tests
    ++ [ furnish.tests."test furnish host index keeps source and context opaque" ]
  );
  inherit (furnish) exceptions;
}
