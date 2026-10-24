{
  project,
  component,
  size,
  bad,
  outputProjection,
}:
let
  inherit (project.inputs.nixpkgs) lib;
  pkgs = project.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  api = project.lib;
  indexes = builtins.genList (i: i) size;
  nameOf = i: "item${toString i}";
  source = project.outPath + "/tests/program/fixtures/sample-tree";
  target = {
    host = {
      name = "host";
      system = "x86_64-linux";
    };
    user.name = "user";
  };
  ownerships = api.ownerships { };
  roster = ownerships.toRoster [
    (ownerships.define.host "host" { system = "x86_64-linux"; })
    (ownerships.define.host "away" { system = "x86_64-linux"; })
    (ownerships.define.user "user" { hosts = [ "host" ]; })
  ];
  declaration = api.lexicon.forRoster { inherit roster; } {
    furnish.directories = map (i: {
      inherit source;
      destination = ".tree/${nameOf i}";
      exclude = [ (if bad then "missing" else "safe-render.nix") ];
      files = [
        {
          names = [ "diagnostics.nix" ];
          hosts = [ "away" ];
        }
        {
          names = [ "default.nix" ];
          representation = "writable";
        }
      ];
    }) indexes;
  };
  args = target // {
    inherit lib pkgs;
    config = {
      networking.hostName = "host";
      lexicon.furnish.declarations = [ ];
    };
  };
  entriesOf =
    aspect: context:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon) (aspect.nixos context).imports
    )).lexicon.furnish.declarations;
  directory =
    context:
    map (entry: {
      inherit (entry) destination representation;
      principal = entry.authority.identity;
    }) (entriesOf declaration context);
  grouped = api.lexicon.forTarget { inherit target; } {
    furnish = {
      files = [
        {
          source = throw "component forced an opaque file source";
          destination = ".ordinary";
        }
      ];
      links = [
        {
          source = "/external";
          names = map (i: if bad && i == 0 then "../bad" else nameOf i) indexes;
          destinations = [
            ".a"
            ".b"
          ];
        }
      ];
    };
  };
  themes = map (
    i:
    (api.lexicon.forTarget { inherit target; } {
      theme = {
        id = if bad then "duplicate" else nameOf i;
        renderers.dms = {
          source = source + "/safe-render.nix";
          output = ".output/${nameOf i}";
        };
      };
    }).nixos
  ) indexes;
  themeEvaluation = lib.evalModules {
    specialArgs.pkgs = pkgs // {
      formats.toml = _: { generate = name: value: builtins.toFile name (builtins.toJSON value); };
    };
    modules = [
      ({ lib, ... }: {
        options = {
          networking.hostName = lib.mkOption {
            type = lib.types.str;
            default = "host";
          };
          assertions = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
          };
          system.extraDependencies = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          environment.systemPackages = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          system.activationScripts = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          systemd.services = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        };
      })
    ]
    ++ themes;
  };
  furnish = api.furnish {
    resolve = throw "component forced the ownership resolver";
    resolveSystem = throw "component forced the system resolver";
  };
  declarations = map (i: {
    label = nameOf i;
    filesystemNamespace = "x86_64-linux/host";
    authority = {
      scope = "user";
      identity = "user";
    };
    managedRoot = "/home/user";
    destination = ".files/${if bad then "duplicate" else nameOf i}";
    representation = "symlink";
    source = {
      kind = "external";
      value = throw "component forced a host-index source";
    };
    generator = throw "component forced a generator";
  }) indexes;
  executor = {
    identity = "component/executor";
    priority = 0;
    enabled = true;
    protocolVersion = 1;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize = declaration: {
      target = {
        kind = "external";
        path = "/external/${declaration.label}";
      };
      cleanupStrategy = "exact-symlink-target";
      selfHealStrategy = "exact-symlink-target";
    };
  };
  values = {
    resource-directory = directory args;
    resource-shared = map (i: directory (args // { user.name = "user${toString i}"; })) indexes;
    resource-grouped = map (entry: entry.destination) (entriesOf grouped args);
    resource-theme =
      let
        entries = themeEvaluation.config.lexicon.furnish.declarations;
        config = builtins.head (
          builtins.filter (entry: entry.destination == ".config/matugen/config.toml") entries
        );
        generated = builtins.fromJSON (builtins.readFile config.source.value);
      in
      {
        destinations = map (entry: entry.destination) entries;
        templates = lib.mapAttrs (_: value: removeAttrs value [ "input_path" ]) generated.templates;
      };
    resource-furnish =
      map
        (entry: {
          destination = entry.filesystemIdentity.destination;
          inherit (entry) target executor;
        })
        (furnish.compile {
          inherit declarations;
          executors = [ executor ];
          provider = furnish.core.offProvider;
        }).manifestData;
    resource-index = builtins.attrNames (
      furnish.core.buildHostIndex {
        inherit declarations;
        principals = [
          {
            authority = {
              scope = "user";
              identity = "user";
            };
            ctx = throw "component forced the index context";
          }
        ];
        provider = furnish.core.offProvider;
      }
    );
  };
in
if outputProjection == "missing" then
  values.${component}.missing
else if outputProjection == "unsupported" then
  throw "component unsupported resource projection"
else
  values.${component}
