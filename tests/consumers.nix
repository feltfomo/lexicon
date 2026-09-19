{
  pkgs,
  nixpkgs,
  lexicon,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  inputs = {
    inherit lexicon;
    nixpkgs = nixpkgs // {
      legacyPackages.${system} = pkgs;
    };
  };
  registry = (import ../examples/registry-minimal/flake.nix).outputs inputs;
  registryExamples = import ../examples/registry-suite.nix { inherit lexicon; };
  ownerships = (import ../examples/ownerships-minimal/flake.nix).outputs inputs;
  furnish = (import ../examples/furnish/flake.nix).outputs inputs;
  program = (import ../examples/program-minimal/flake.nix).outputs inputs;
  ownershipResult = ownerships.lib.result;
  furnishManifest = furnish.lib.manifest;
  programResult = program.lib.result;
  registrySummary = registry.lib.summary;
  registryChanged = registryExamples.minimal.changed;
  registryChangedExpected = registrySummary // {
    hosts = [
      "vault"
      "workstation"
    ];
  };
  praxisPackage = lexicon.packages.${system}.praxis;
in
pkgs.runCommandLocal "lexicon-consumer-checks"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    test ${pkgs.lib.escapeShellArg (builtins.toJSON registrySummary)} = \
      ${pkgs.lib.escapeShellArg (
        builtins.toJSON {
          systems = [ "x86_64-linux" ];
          hosts = [ "workstation" ];
          users = [ "river" ];
        }
      )}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON registryExamples.minimal.result)} = \
      ${pkgs.lib.escapeShellArg (builtins.toJSON registrySummary)}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON registryChanged)} = \
      ${pkgs.lib.escapeShellArg (builtins.toJSON registryChangedExpected)}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON ownershipResult)} = \
      ${pkgs.lib.escapeShellArg (builtins.toJSON { editor = "helix"; })}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON furnishManifest)} = \
      ${pkgs.lib.escapeShellArg (
        builtins.toJSON [
          {
            destination = "/home/river/.config/paperkite/settings.conf";
            onConflict = "error";
            representation = "symlink";
          }
        ]
      )}
    test ${pkgs.lib.escapeShellArg (builtins.toJSON programResult)} = \
      ${pkgs.lib.escapeShellArg (
        builtins.toJSON {
          furnishIntegration = false;
          mode = "focused";
          outputs = [ "nixos" ];
        }
      )}
    ${praxisPackage}/bin/praxis --version > actual
    printf 'praxis 1.0.0\n' > expected
    cmp expected actual
    test -e ${furnish.nixosConfigurations.demo.config.lexicon.furnish.manifestPath}
    test -e ${program.checks.${system}.example}
    touch "$out"
  ''
