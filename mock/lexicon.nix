# contribute the nixos fields that the identity model does not carry.
{
  lib,
  fx,
  nixpkgs,
}:
let
  library = import ../src { inherit lib fx; };

  contributedFields =
    { t, ... }:
    {
      fields = {
        host = [
          {
            name = "stateVersion";
            type = t.String;
          }
          {
            name = "hardware";
            type = t.String;
          }
        ];

        user = [
          {
            name = "elevated";
            type = t.Bool;
            default = false;
          }
        ];
      };
    };

  # the output layer receives package sets so it does not instantiate nixpkgs
  # while walking the declaration tree.
  packageSetFor = system: import nixpkgs { inherit system; };

  capabilities = {
    # eval-config is absent from nixpkgs lib, so pass it as a capability.
    systemEvaluator = arguments: import (nixpkgs + "/nixos/lib/eval-config.nix") arguments;

    inherit packageSetFor;

    # the binary lexicon manages a host with, built with the package set this
    # configuration already makes so no second nixpkgs enters the evaluation
    lexiconPackage = system: (packageSetFor system).callPackage ../cli/package.nix { };
  };

  configure =
    root:
    library.configure {
      inherit root capabilities;
      contributions = [ contributedFields ];
    };
in
{
  inherit library configure;

  inherit (capabilities) packageSetFor;
}
