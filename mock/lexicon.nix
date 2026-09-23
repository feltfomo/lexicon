# where this configuration meets lexicon. the fields nixos needs and the
# identity model does not carry are contributed here
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

  # the attribute that evaluates a system is published on the flake output of
  # the nixpkgs tree and is absent from the lib imported out of it, so it can
  # only arrive as a capability. read 2026-09-21
  capabilities = {
    systemEvaluator = arguments: import (nixpkgs + "/nixos/lib/eval-config.nix") arguments;

    # instantiating a package set is a choice about this tree and about the
    # systems it builds for, so the output layer is handed sets already made
    # rather than the tree to make them from
    packageSetFor = system: import nixpkgs { inherit system; };
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
