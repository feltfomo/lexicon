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
    lexicon = changedProgram;
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
    "homeManager"
    "files"
    "links"
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
  claimedTemplates =
    templates:
    selectionProgram {
      theme = {
        id = "claimed-list";
        users = [ "alice" ];
        inherit templates;
      };
    };
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
  fileManifest = filesOutput.nixosConfigurations.file.config.lexicon.furnish.manifestData;
  firstFile = builtins.head fileManifest;
  tests = {
    "test minimal" = {
      expr = samples."minimal.result";
      expected = {
        furnishIntegration = false;
        mode = "focused";
        outputs = [ "nixos" ];
      };
    };
    "test predictable edit" = {
      expr = samples."minimal.changed".mode;
      expected = "quiet";
    };
    "test sparse package" = {
      expr = samples."capabilities.package".outputs;
      expected = [ "homeManager" ];
    };
    "test sparse imports" = {
      expr = samples."capabilities.imports".outputs;
      expected = [ "homeManager" ];
    };
    "test sparse nixos" = {
      expr = samples."capabilities.nixos";
      expected = {
        furnishRuntime = false;
        normalUser = true;
        outputs = [ "nixos" ];
      };
    };
    "test sparse empty" = {
      expr = samples."capabilities.empty".outputs;
      expected = [ ];
    };
    "test empty template list is inert" = {
      expr = builtins.attrNames emptyTemplateList;
      expected = [ ];
    };
    "test a claim beside an empty template list stays inert" = {
      expr = builtins.attrNames (claimedTemplates [ ]);
      expected = [ ];
    };
    "test a claim beside templates selects the whole theme through ownerships" = {
      expr =
        (claimedTemplates [
          {
            renderers.dms = {
              source = ./program/fixtures/sample-tree/safe-render.nix;
              output = ".config/editor/dms-palette";
            };
          }
        ]).nixos
          moduleArgs;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit '\\$\\.theme': axis 'user' is narrowed on by claim \\{ set = \\[ \"alice\" \\]; tag = \"include\"; \\}";
    };
    "test studio home module graph" = {
      expr =
        samples."studio.result".package == "helix"
        && samples."studio.result".editor == "hx"
        && samples."studio.result".homeUser == "river"
        && samples."studio.result".homeDirectory == "/home/river"
        && samples."studio.result".homeStateVersion == "26.05";
      expected = true;
    };
    "test file automatic" = {
      expr =
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
      expected = true;
    };
    "test ownership selection" = {
      expr =
        samples."ownerships.result".alice.files == [ "/home/alice/.config/helix/config.toml" ]
        && samples."ownerships.result".bob.files == [ ];
      expected = true;
    };
    "test den boundary" = {
      expr = samples."den.result".entryCount == 1 && samples."den.result".authority.identity == "river";
      expected = true;
    };
    "test direct claims rejected" = {
      expr = directClaimFails;
      expected = true;
    };
    "test file target required" = {
      expr = missingFileUserFails;
      expected = true;
    };
    "test ordinary nixos opaque" = {
      expr = (builtins.head ordinaryNixos.imports).users.users.river.isNormalUser;
      expected = true;
    };
  };
in
{
  inherit samples tests;
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
      "lucid"
      "noctalia"
      "serpantinum"
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
}
