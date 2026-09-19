{ lexicon, nixpkgs }:
let
  example = name: (import (../examples + "/${name}/flake.nix")).outputs { inherit lexicon nixpkgs; };
  minimal = example "furnish";
  policies = example "furnish-policies";
  studio = example "furnish-studio";

  projectEntry = entry: {
    inherit (entry)
      authority
      onConflict
      provenance
      representation
      ;
    inherit (entry.filesystemIdentity) canonical destination namespace;
  };

  furnish = lexicon.lib.furnish {
    resolve = _: _: throw "unused Furnish documentation resolver";
    resolveSystem = _: _: throw "unused Furnish documentation system resolver";
  };
  runtimeModule = lexicon.lib.furnishRuntime { };
  source = ../examples/furnish/settings.conf;
  declaration = {
    label = "disabled inspection";
    filesystemNamespace = "x86_64-linux/studio";
    authority = {
      scope = "user";
      identity = "river";
    };
    managedRoot = "/home/river";
    destination = ".config/paperkite/settings.conf";
    representation = "symlink";
    source = {
      kind = "path";
      value = source;
    };
    provenance.source = "tests/furnish-examples.nix";
  };

  mkSystem =
    extra:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        runtimeModule
        {
          boot.isContainer = true;
          networking.hostName = "studio";
          users.users.river.isNormalUser = true;
          system.stateVersion = "26.05";
        }
        extra
      ];
    };
  disabled = mkSystem {
    lexicon.furnish.declarations = [ declaration ];
  };
  emptyEnabled = mkSystem {
    lexicon.furnish.enable = true;
  };
  options = minimal.nixosConfigurations.demo.options.lexicon.furnish;
  optionNames =
    builtins.filter (name: name != "state") (builtins.attrNames options)
    ++ map (name: "state.${name}") (builtins.attrNames options.state);
  helperDeclarations = furnish.files.mkDeclarations {
    filesystemNamespace = "x86_64-linux/studio";
    principals = [
      {
        authority = {
          scope = "user";
          identity = "river";
        };
      }
      {
        authority = {
          scope = "system";
          identity = "x86_64-linux/studio";
        };
        managedRoot = "/etc";
      }
    ];
    files = [
      {
        src = source;
        dest = ".config/paperkite/settings.conf";
      }
    ];
  };
  helperEntry = builtins.head helperDeclarations;
  compiler = furnish.compile {
    provider = furnish.core.offProvider;
    raw.kept = true;
  };
  manifestEntry = builtins.head minimal.nixosConfigurations.demo.config.lexicon.furnish.manifestData;
  helperSample = {
    inherit (helperEntry) authority;
    count = builtins.length helperDeclarations;
    inherit (helperEntry) destination;
    inherit (helperEntry) label;
    inherit (helperEntry) managedRoot;
    inherit (helperEntry) representation;
    sourceKind = helperEntry.source.kind;
  };
in
{
  samples = {
    "minimal.manifest" = minimal.lib.manifest;
    "minimal.runtime" = minimal.lib.runtime;
    "policies.manifest" = policies.lib.manifest;
    "studio.manifest" = studio.lib.manifest;
    "runtime.disabled" = {
      enabled = disabled.config.lexicon.furnish.enable;
      manifest = map projectEntry disabled.config.lexicon.furnish.manifestData;
      manifestAvailable = disabled.config.lexicon.furnish.manifestPath != null;
      serviceEnabled = disabled.config.systemd.services ? furnish;
    };
    "runtime.empty" = {
      activationEnabled = emptyEnabled.config.system.activationScripts ? furnish;
      entryCount = builtins.length emptyEnabled.config.lexicon.furnish.manifestData;
      manifestAvailable = emptyEnabled.config.lexicon.furnish.manifestPath != null;
      serviceEnabled = emptyEnabled.config.systemd.services ? furnish;
    };
    "helper.generated" = helperSample;
    "compiler.empty" = {
      entryCount = builtins.length compiler.manifestData;
      inherit (compiler) manifestPath;
      inherit (compiler) raw;
    };
    "contract.values" = {
      capabilities = furnish.contract.capabilities;
      conflictPolicies = furnish.contract.conflictPolicies;
      diagnosticSchemaVersion = furnish.contract.diagnosticSchemaVersion;
      ledger = furnish.contract.ledger;
      schemaVersion = furnish.contract.schemaVersion;
      strategies = furnish.contract.strategies;
    };
    "runtime.native" = {
      inherit (manifestEntry) cleanupStrategy;
      inherit (manifestEntry) executor;
      inherit (manifestEntry) representation;
      inherit (manifestEntry) schemaVersion;
      inherit (manifestEntry) selfHealStrategy;
    };
  };

  flakeExports = builtins.filter (
    name:
    builtins.elem name [
      "furnish"
      "furnishRuntime"
    ]
  ) (builtins.attrNames lexicon.lib);
  exports = builtins.attrNames furnish;
  contractExports = builtins.attrNames furnish.contract;
  coreExports = builtins.attrNames furnish.core;
  filesExports = builtins.attrNames furnish.files;
  resultFields = builtins.attrNames compiler;
  manifestEntryFields = builtins.attrNames manifestEntry;
  inherit optionNames;

  ok =
    assert
      builtins.attrNames furnish == [
        "compile"
        "contract"
        "core"
        "files"
        "runtime"
      ];
    assert
      optionNames == [
        "declarations"
        "enable"
        "ledgerPath"
        "manifestData"
        "manifestPath"
        "state.durability"
        "state.path"
        "state.requiresMountsFor"
      ];
    assert builtins.length helperDeclarations == 1;
    assert
      manifestEntry.provenance == {
        declaration = "paperkite settings";
        source = "paperkite settings";
      };
    assert compiler.manifestData == [ ];
    assert compiler.manifestPath == null;
    assert disabled.config.lexicon.furnish.manifestPath == null;
    assert !(disabled.config.systemd.services ? furnish);
    assert emptyEnabled.config.lexicon.furnish.manifestData == [ ];
    assert emptyEnabled.config.lexicon.furnish.manifestPath != null;
    assert emptyEnabled.config.systemd.services ? furnish;
    assert furnish.contract.schemaVersion == 2;
    assert furnish.contract.diagnosticSchemaVersion == 1;
    assert furnish.contract.ledger.schemaVersion == 2;
    true;
}
