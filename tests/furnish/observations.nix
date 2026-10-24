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
  poison = resource.ok && furnish.cases.furnish-host-index-keeps-source-and-context-opaque;
  inherit (furnish) exceptions;
}
