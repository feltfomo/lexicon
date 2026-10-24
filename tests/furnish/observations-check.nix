{
  pkgs,
  nixpkgsSource,
  axiomSource,
  krisisSource,
}:
let
  retained = pkgs.writeText "furnish-effects-source" "retained";
  environment = ''
    let
      source = ${../..};
      lib = import ${nixpkgsSource}/lib;
      axiom = import ${axiomSource}/src { inherit lib; };
      krisisSource.lib = {
        krisis = import ${krisisSource}/src;
        qualifiedNixEffectsSource = ${krisisSource.lib.qualifiedNixEffectsSource};
      };
      dependenciesFor = args: import (source + "/src/dependencies.nix") {
        inherit lib axiom krisisSource;
        krisis = args.krisis or null;
      };
      deps = dependenciesFor { };
      inherit (deps) krisis;
      lexicon.lib = {
        lexicon = import (source + "/src/lexicon") {
          inherit lib axiom krisis;
          mkCoordinator = throw "resource observations forced a coordinator";
        };
        furnish = args: import (source + "/src/furnish") (args // dependenciesFor args);
      };
      pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  '';
  setup = pkgs.writeText "resource-observations.nix" (
    environment
    + ''
      in import (source + "/tests/furnish/observations.nix") {
        inherit lib pkgs axiom krisis lexicon;
        retainedPath = "${retained}";
      }
    ''
  );
  terminalSetup = pkgs.writeText "terminal-observations.nix" (
    environment
    + ''
      in import (source + "/tests/furnish/terminals.nix") {
        inherit lib axiom lexicon krisisSource source;
      }
    ''
  );
in
pkgs.runCommandLocal "resource-observation-tests"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.python3
    ];
  }
  ''
    set -euo pipefail
    python3 ${../../verification/components/contracts.py} --family resources --setup ${setup} --output "$TMPDIR/contracts/resources"
    python3 ${../../verification/components/contracts.py} --family terminals --setup ${terminalSetup} --output "$TMPDIR/contracts/terminals"
    mkdir "$out"
    cp -r "$TMPDIR/contracts/." "$out/"
  ''
