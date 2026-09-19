{ lexicon, nixpkgs }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (pkgs) lib;
  examples = import ../examples/program-suite.nix { inherit lexicon nixpkgs; };
  minimalOutput = (import ../examples/program-minimal/flake.nix).outputs { inherit lexicon nixpkgs; };
  filesOutput = (import ../examples/program-files/flake.nix).outputs { inherit lexicon nixpkgs; };
  changedProgram = import ../examples/program-minimal/program-binding.nix { inherit lexicon system; };
  changedSource =
    builtins.replaceStrings [ "PAPERKITE_MODE = \"focused\"" ] [ "PAPERKITE_MODE = \"quiet\"" ]
      (builtins.readFile ../examples/program-minimal/paperkite.nix);
  changedPaperkite = import (builtins.toFile "program-minimal-changed.nix" changedSource) {
    program = changedProgram;
  };
  changedSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      (import ../examples/program-minimal/configuration.nix { paperkite = changedPaperkite; })
    ];
  };
  samples = {
    "minimal.result" = examples.minimal.result;
    "minimal.changed" = examples.minimal.result // {
      mode = changedSystem.config.environment.variables.PAPERKITE_MODE;
    };
    "capabilities.package" = examples.capabilities.results.package;
    "capabilities.imports" = examples.capabilities.results.imports;
    "capabilities.nixos" = examples.capabilities.results.nixos;
    "capabilities.empty" = examples.capabilities.results.empty;
    "files.file" = examples.files.file;
    "files.directory" = examples.files.directory;
    "themes.result" = examples.themes.result;
    "ownerships.result" = examples.ownerships.result;
    "den.result" = examples.den.result;
    "studio.result" = examples.studio.result;
  };
  constructorNames = builtins.filter (
    name:
    builtins.elem name [
      "program"
      "programDen"
      "programDirect"
      "programOwnerships"
    ]
  ) (builtins.attrNames lexicon.lib);
  claimFields = [
    "hosts"
    "users"
    "exceptHosts"
    "exceptUsers"
    "when"
  ];
  specFields = claimFields ++ [
    "pkg"
    "nixos"
    "imports"
    "files"
    "directories"
    "theme"
  ];
  lifecycleFields = [
    "representation"
    "onConflict"
    "provenance"
  ];
  fileFields =
    claimFields
    ++ [
      "dest"
      "src"
      "label"
    ]
    ++ lifecycleFields;
  directoryFields =
    claimFields
    ++ [
      "src"
      "dest"
      "exclude"
      "files"
    ]
    ++ lifecycleFields;
  directoryRuleFields = claimFields ++ [ "names" ] ++ lifecycleFields;
  themeValueFields = [
    "source"
    "output"
    "subdir"
    "placedAs"
    "subId"
    "reload"
    "native"
  ];
  themeFields =
    claimFields
    ++ [
      "id"
      "renderers"
      "templates"
    ]
    ++ themeValueFields;
  templateFields = claimFields ++ themeValueFields ++ [ "renderers" ];
  rendererFields = claimFields ++ themeValueFields ++ [ "sharedWith" ];
  target = {
    host = {
      name = "studio";
      inherit system;
    };
    user.name = "river";
  };
  direct = lexicon.lib.programDirect { inherit target; };
  systemDirect = lexicon.lib.programDirect { target.host = target.host; };
  ownerships = lexicon.lib.ownerships { };
  themeRoster = import ../examples/program-ownerships/roster.nix { inherit ownerships system; };
  selectionProgram = lexicon.lib.programOwnerships { roster = themeRoster; };
  emptyTemplateList = direct {
    theme = {
      id = "empty-list";
      templates = [ ];
    };
  };
  moduleArgs = {
    inherit lib pkgs;
    config.networking.hostName = "ignored";
  };
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  directClaimFails = fails (direct {
    users = [ "river" ];
  });
  templateListTopClaimFails = fails (selectionProgram {
    theme = {
      id = "mixed-list";
      users = [ "alice" ];
      templates = [ ];
    };
  });
  missingFileUserFails = fails (
    (systemDirect {
      files = [
        {
          dest = ".config/program/missing-user";
          src = ../examples/program-files/sources/settings.conf;
        }
      ];
    }).nixos
      moduleArgs
  );
  ordinaryNixos = (direct { nixos.users.users.river.isNormalUser = true; }).nixos moduleArgs;
  boundary = import ./program {
    inherit
      lib
      pkgs
      lexicon
      ;
    axiom = lexicon.inputs.axiom.lib.axiom { inherit lib; };
    krisis = lexicon.inputs.krisis.lib.krisis {
      inherit lib;
      axiom = lexicon.inputs.axiom.lib.axiom { inherit lib; };
    };
  };
  fileManifest = filesOutput.nixosConfigurations.file.config.lexicon.furnish.manifestData;
  firstFile = builtins.head fileManifest;
  cases = {
    minimal =
      samples."minimal.result" == {
        furnishIntegration = false;
        mode = "focused";
        outputs = [ "nixos" ];
      };
    predictableEdit = samples."minimal.changed".mode == "quiet";
    sparsePackage = samples."capabilities.package".outputs == [ "homeManager" ];
    sparseImports = samples."capabilities.imports".outputs == [ "homeManager" ];
    sparseNixos =
      samples."capabilities.nixos" == {
        furnishRuntime = false;
        normalUser = true;
        outputs = [ "nixos" ];
      };
    sparseEmpty = samples."capabilities.empty".outputs == [ ];
    emptyTemplateListIsInert = builtins.attrNames emptyTemplateList == [ ];
    templateListTopClaimsRejected = templateListTopClaimFails;
    studioHomeModuleGraph =
      samples."studio.result".package == "helix"
      && samples."studio.result".editor == "hx"
      && samples."studio.result".homeUser == "river"
      && samples."studio.result".homeDirectory == "/home/river"
      && samples."studio.result".homeStateVersion == "26.05";
    fileAutomatic =
      samples."files.file".outputs == [ "nixos" ]
      && samples."files.file".furnishEnabled
      && samples."files.file".serviceEnabled
      &&
        firstFile.authority == {
          scope = "user";
          identity = "river";
        }
      && firstFile.managedRoot == "/home/river"
      && firstFile.filesystemIdentity.namespace == "${system}/studio";
    ownershipSelection =
      samples."ownerships.result".alice.files == [ "/home/alice/.config/helix/config.toml" ]
      && samples."ownerships.result".bob.files == [ ];
    denBoundary =
      samples."den.result".entryCount == 1 && samples."den.result".authority.identity == "river";
    directClaimsRejected = directClaimFails;
    fileTargetRequired = missingFileUserFails;
    ordinaryNixosOpaque = (builtins.head ordinaryNixos.imports).users.users.river.isNormalUser;
    callbackCompatibility = boundary.ok;
  };
  failing = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit samples cases;
  inventories = {
    constructors = constructorNames;
    claims = claimFields;
    spec = specFields;
    file = fileFields;
    directory = directoryFields;
    directoryRule = directoryRuleFields;
    theme = themeFields;
    template = templateFields;
    renderer = rendererFields;
    target = [
      "host"
      "user"
    ];
    host = [
      "name"
      "system"
      "id"
    ];
    user = [
      "name"
      "home"
    ];
    backends = [
      "caelestia"
      "dms"
      "end4-pc"
      "illogical-impulse"
      "noctalia"
    ];
    outputs = [
      "homeManager"
      "nixos"
    ];
  };
  expectedFailures = [
    "direct.claim"
    "direct.file-without-user"
  ];
  ok =
    if failing == [ ] then
      true
    else
      throw "Program examples failed: ${lib.concatStringsSep ", " failing}";
}
