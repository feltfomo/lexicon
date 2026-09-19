{ lexicon, nixpkgs }:
let
  samples = import ../examples/praxis-suite.nix { inherit lexicon nixpkgs; };
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  result = lexicon.lib.praxis {
    inherit pkgs;
    commands.probe = [ "${pkgs.coreutils}/bin/true" ];
  };
  adapters = lexicon.lib.praxisAdapters { inherit (nixpkgs) lib; };
  expected = {
    minimal.names = [ "inspect" ];
    commands = {
      names = [
        "arguments"
        "check"
        "inspect"
        "list"
        "summary"
        "verify"
      ];
      verifyKinds = [
        "command"
        "command"
      ];
    };
    parameters = {
      names = [
        "name"
        "greeting"
      ];
      types = [
        "int"
        "bool"
        "path"
      ];
    };
    outputs = {
      apps = [
        "check"
        "unit"
        "work"
      ];
      packages = [
        "check"
        "unit"
        "work"
      ];
      checks = [ "unit" ];
      hasDevShell = true;
    };
    workflow = {
      names = [
        "acknowledge"
        "authenticate"
        "publish"
      ];
      publishKinds = [
        "prompt"
        "prompt"
        "run"
      ];
    };
    ownerships = {
      names = [
        "common"
        "local"
        "review"
      ];
      hostChoices = [
        "aarch64-linux/away"
        "x86_64-linux/desk"
      ];
      userChoices = [ "river" ];
      denMatches = true;
    };
    project = {
      names = [
        "build"
        "check"
        "inspect"
        "verify"
      ];
      verifyLabels = [
        "inspect"
        "check"
      ];
    };
  };
  ok =
    samples.minimal == expected.minimal
    && samples.commands == expected.commands
    && samples.parameters == expected.parameters
    && samples.outputs == expected.outputs
    && samples.workflow == expected.workflow
    && samples.ownerships == expected.ownerships
    && samples.project == expected.project
    && samples.scripts.discoverRoot == "flake.nix"
    && samples.scripts.sourceKind.kind == "script"
    && samples.scripts.sourceKind.rootRelative
    && samples.scripts.generatedKind.kind == "script"
    && !(samples.scripts.generatedKind.rootRelative or false)
    && samples.scripts.checks == [ "source-check" ];
in
{
  inherit samples ok;
  inventories = {
    constructors = builtins.filter (nixpkgs.lib.hasPrefix "praxis") (builtins.attrNames lexicon.lib);
    projectFields = [
      "pkgs"
      "name"
      "commands"
      "tasks"
      "check"
      "atRoot"
      "wrappers"
      "perCommand"
      "devShell"
      "root"
      "cwd"
      "discoverRoot"
      "requireRoot"
      "ui"
      "checks"
      "ownership"
      "units"
    ];
    actionFields = [
      "command"
      "shell"
      "script"
      "prompt"
      "interpreter"
      "args"
      "forwardArgs"
      "interactive"
      "confirm"
      "label"
      "condition"
      "cwd"
      "env"
      "timeout"
      "ui"
      "localFlake"
    ];
    parameterFields = [
      "name"
      "description"
      "type"
      "positional"
      "required"
      "env"
      "short"
      "sensitive"
      "choices"
      "default"
    ];
    parameterTypes = [
      "string"
      "int"
      "bool"
      "path"
    ];
    resultFields = builtins.attrNames result;
    adapterFields = builtins.attrNames adapters;
  };
}
