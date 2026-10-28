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
  cells = {
    inventory = resource.probe;
    materialization = furnish.callbackProbe;
    inherit (furnish) exceptions;
  };

  principal = name: [
    {
      destination = ".opaque";
      principal = name;
    }
    {
      destination = ".inventory/root.nix";
      principal = name;
    }
  ];
in
# the opaque payload transport is pinned by every case of
# declarations.resource-effects and by furnish.effects' host index case.
# inventory and materializer counts and the furnish error contexts are checked
# from these cells by the events flake check
cells
// {
  tests = {
    "test one static inventory serves both principals" = {
      expr = cells.inventory;
      expected = {
        first = principal "alice";
        second = principal "bob";
      };
    };

    "test repeated demand sees one retained materialization" = {
      expr =
        cells.materialization.first == cells.materialization.second
        && lib.hasPrefix "${builtins.storeDir}/" cells.materialization.first;
      expected = true;
    };

    "test a provider exception surfaces unchanged" = {
      expr = cells.exceptions.provider;
      expectedError.type = "ThrownError";
      expectedError.msg = "resource effects provider exception";
    };

    "test a materializer exception surfaces unchanged" = {
      expr = cells.exceptions.materializer;
      expectedError.type = "ThrownError";
      expectedError.msg = "resource effects materializer exception";
    };
  };
}
