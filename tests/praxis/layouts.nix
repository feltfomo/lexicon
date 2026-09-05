{ praxis, pkgs }:
let
  inline = praxis {
    inherit pkgs;
    discoverRoot = "flake.nix";
    commands = {
      fmt = {
        description = "Format the project";
        steps = [
          {
            exec = [
              "nix"
              "fmt"
            ];
          }
        ];
      };
      test = {
        description = "Run project tests";
        runtimeInputs = [ pkgs.bash ];
        steps = [
          {
            script = "scripts/test.sh";
            interpreter = "bash";
            forwardArgs = true;
          }
        ];
      };
      build = {
        description = "Build a selected flake output";
        parameters = [
          {
            name = "target";
            positional = true;
            default = ".#default";
          }
        ];
        steps = [
          {
            exec = [
              "nix"
              "build"
              { param = "target"; }
            ];
            forwardArgs = true;
          }
        ];
      };
      gate = {
        description = "Format and test the project";
        steps = [
          { command = "fmt"; }
          { command = "test"; }
        ];
      };
    };
  };
  single = import ./fixtures/praxis.nix { inherit praxis pkgs; };
  modular = import ./fixtures/modular { inherit praxis pkgs; };
in
inline.manifest == single.manifest
&& inline.manifest == modular.manifest
&& inline.manifests.gate == modular.manifests.gate
&& builtins.attrNames inline.apps == builtins.attrNames modular.apps
&& builtins.attrNames single.packages == builtins.attrNames modular.packages
