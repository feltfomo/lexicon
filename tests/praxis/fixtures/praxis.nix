{ praxis, pkgs }:
praxis {
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
}
