{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      tasks = import ./. {
        inherit pkgs;
        praxis = inputs.lexicon.lib.praxis;
      };
    in
    {
      apps = tasks.apps // {
        praxis = {
          type = "app";
          program = "${tasks.cli}/bin/praxis";
        };
      };
      packages = tasks.packages // {
        praxis = tasks.package;
      };
      devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
    };
}
