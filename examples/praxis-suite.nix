{ lexicon, nixpkgs }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  inputs = { inherit lexicon nixpkgs; };
  # every example is loaded the way the installed dispatcher loads it:
  # through the praxis output its flake.nix exposes
  compile =
    directory:
    let
      project = (import (directory + "/flake.nix")).outputs inputs;
    in
    lexicon.lib.praxis (
      {
        inherit pkgs;
        root = directory;
      }
      // project.praxis {
        inherit pkgs;
        root = directory;
      }
    );
  minimal = compile ./praxis-minimal;
  commands = compile ./praxis-commands;
  parameters = compile ./praxis-parameters;
  scripts = compile ./praxis-scripts;
  workflow = compile ./praxis-workflow;
  project = compile ./praxis-project;
  outputsFlake = (import ./praxis-outputs/flake.nix).outputs { inherit nixpkgs lexicon; };
  ownershipsFlake = (import ./praxis-ownerships/flake.nix).outputs { inherit nixpkgs lexicon; };
in
{
  minimal.names = builtins.attrNames minimal.manifest.commands;
  commands = {
    names = builtins.attrNames commands.manifest.commands;
    verifyKinds = map (step: step.kind) commands.manifest.commands.verify.steps;
  };
  parameters = {
    names = map (parameter: parameter.name) parameters.manifest.commands.greet.parameters;
    types = map (parameter: parameter.type) parameters.manifest.commands.inspect.parameters;
  };
  scripts = {
    discoverRoot = scripts.manifest.project.discoverRoot;
    sourceKind = builtins.head scripts.manifest.commands.source-script.steps;
    generatedKind = builtins.head scripts.manifest.commands.generated-script.steps;
    checks = builtins.attrNames scripts.checks;
  };
  outputs = {
    apps = builtins.attrNames outputsFlake.apps.${system};
    packages = builtins.attrNames outputsFlake.packages.${system};
    checks = builtins.attrNames outputsFlake.checks.${system};
    hasDevShell = outputsFlake ? devShells;
  };
  workflow = {
    names = builtins.attrNames workflow.manifest.commands;
    publishKinds = map (step: step.kind) workflow.manifest.commands.publish.steps;
  };
  ownerships = {
    names = ownershipsFlake.lib.availability.names;
    hostChoices = ownershipsFlake.lib.choices.host.choices;
    userChoices = ownershipsFlake.lib.choices.user.choices;
    denMatches = ownershipsFlake.lib.denChoices == ownershipsFlake.lib.choices;
  };
  project = {
    names = builtins.attrNames project.manifest.commands;
    verifyLabels = map (step: step.label) project.manifest.commands.verify.steps;
  };
  advertised = {
    minimal = builtins.attrNames minimal.manifest.commands;
    commands = builtins.attrNames commands.manifest.commands;
    parameters = builtins.attrNames parameters.manifest.commands;
    scripts = builtins.attrNames scripts.manifest.commands;
    workflow = builtins.attrNames workflow.manifest.commands;
    project = builtins.attrNames project.manifest.commands;
  };
}
