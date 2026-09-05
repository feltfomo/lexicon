{ praxis, pkgs }:
praxis {
  inherit pkgs;
  discoverRoot = "flake.nix";
  commands = {
    fmt = import ./fmt.nix;
    test = import ./test.nix { inherit pkgs; };
    build = import ./build.nix;
    gate = import ./gate.nix;
  };
}
