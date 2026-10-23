{
  pkgs,
  nixpkgsSource,
  axiomSource,
  krisisSource,
}:
let
  setup = pkgs.writeText "ownerships-observations.nix" ''
    let
      lib = import ${nixpkgsSource}/lib;
      axiom = import ${axiomSource}/src { inherit lib; };
      krisisSource.lib = {
        krisis = import ${krisisSource}/src;
        qualifiedNixEffectsSource = ${krisisSource.lib.qualifiedNixEffectsSource};
      };
      ownerships = args:
        import ${../../src/ownerships} (
          (import ${../../src}/dependencies.nix {
            inherit lib krisisSource;
            axiom = args.axiom or axiom;
            krisis = args.krisis or null;
          }) // builtins.intersectAttrs { descriptors = null; relations = null; } args
        );
    in import ${./.}/observations.nix { inherit lib axiom ownerships; }
  '';
in
pkgs.runCommandLocal "ownerships-observation-tests"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.python3
    ];
  }
  ''
    set -euo pipefail
    python3 ${../../verification/components/contracts.py} --setup ${setup} --output "$TMPDIR/contracts"
    mkdir "$out"
    cp -r "$TMPDIR/contracts/." "$out/"
  ''
