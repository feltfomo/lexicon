{
  pkgs,
  nixpkgsSource,
  axiomSource,
  krisisSource,
}:
let
  setup = pkgs.writeText "compiler-observations.nix" ''
    let
      lib = import ${nixpkgsSource}/lib;
      axiom = import ${axiomSource}/src { inherit lib; };
      krisisSource.lib = {
        krisis = import ${krisisSource}/src;
        qualifiedNixEffectsSource = ${krisisSource.lib.qualifiedNixEffectsSource};
      };
      deps = import ${../../src}/dependencies.nix { inherit lib axiom krisisSource; };
      compiler = import ${../../src}/declarations { inherit lib axiom; inherit (deps) krisis; };
    in import ${./.}/observations.nix { inherit lib axiom compiler; }
  '';
in
pkgs.runCommandLocal "compiler-observation-tests"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.python3
    ];
  }
  ''
    set -euo pipefail
    python3 ${../../verification/components/contracts.py} --family compiler --setup ${setup} --output "$TMPDIR/contracts"
    mkdir "$out"
    cp -r "$TMPDIR/contracts/." "$out/"
  ''
