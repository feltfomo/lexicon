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
        "path"
        "bool"
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
  documented =
    name:
    nixpkgs.lib.nameValuePair "test ${name} example matches its documented result" {
      expr = samples.${name};
      expected = expected.${name};
    };
  stepKind = step: {
    inherit (step) kind;
    rootRelative = step.rootRelative or false;
  };
  tests =
    builtins.listToAttrs (
      map documented [
        "minimal"
        "commands"
        "parameters"
        "outputs"
        "workflow"
        "ownerships"
        "project"
      ]
    )
    // {
      "test script example discovers the flake root" = {
        expr = samples.scripts.discoverRoot;
        expected = "flake.nix";
      };
      "test source scripts resolve relative to the root" = {
        expr = stepKind samples.scripts.sourceKind;
        expected = {
          kind = "script";
          rootRelative = true;
        };
      };
      "test generated scripts are store paths rather than root relative" = {
        expr = stepKind samples.scripts.generatedKind;
        expected = {
          kind = "script";
          rootRelative = false;
        };
      };
      "test script example registers only its source check" = {
        expr = samples.scripts.checks;
        expected = [ "source-check" ];
      };
    };
in
{
  inherit samples tests;
  inventories = {
    constructors = builtins.filter (nixpkgs.lib.hasPrefix "praxis") (builtins.attrNames lexicon.lib);
    projectFields = [
      "pkgs"
      "name"
      "commands"
      "tasks"
      "scope"
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
      "description"
      "type"
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
