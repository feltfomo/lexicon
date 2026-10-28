# furnish lowering and compilation. links lowers size external links, directory
# expands size directories over the fixture tree, shared compiles one directory
# declaration in size user contexts, grouped expands size names into two roots
# beside an opaque file source, compile builds the manifest for size declarations
# and index builds the host index while sources, generators and context throw
{
  api,
  lib,
  pkgs,
  size,
  names,
  fixtures,
  ...
}:
let
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

  args = target // {
    inherit lib pkgs;
    config = {
      networking.hostName = "host";
      lexicon.furnish.declarations = [ ];
    };
  };

  # native imports also hold module functions, which carry no declarations
  declarationsOf =
    aspect: context:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon) (aspect.nixos context).imports
    )).lexicon.furnish.declarations;

  # every directory excludes the renderer source, reserves diagnostics.nix for
  # an away host and selects default.nix as writable
  directories = api.lexicon.forRoster { inherit roster; } {
    furnish.directories = map (name: {
      source = fixtures + "/directory";
      destination = ".tree/${name}";
      exclude = [ "safe-render.nix" ];
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
    }) names;
  };

  directory =
    context:
    map (entry: {
      inherit (entry) destination representation;
      principal = entry.authority.identity;
    }) (declarationsOf directories context);

  furnish = api.furnish {
    resolve = throw "furnish workload forced the ownership resolver";
    resolveSystem = throw "furnish workload forced the system resolver";
  };

  declarations = map (name: {
    label = name;
    filesystemNamespace = "x86_64-linux/host";
    authority = {
      scope = "user";
      identity = "user";
    };
    managedRoot = "/home/user";
    destination = ".files/${name}";
    representation = "symlink";
    source = {
      kind = "external";
      value = throw "furnish workload forced a host-index source";
    };
    generator = throw "furnish workload forced a generator";
  }) names;

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
in
{
  links = map (entry: entry.destination) (
    declarationsOf (api.lexicon.forTarget { inherit target; } {
      furnish.links = map (name: {
        source = "/external/${name}";
        destination = ".links/${name}";
      }) names;
    }) args
  );

  directory = directory args;

  shared = builtins.genList (
    index: directory (args // { user.name = "user${toString index}"; })
  ) size;

  grouped = map (entry: entry.destination) (
    declarationsOf (api.lexicon.forTarget { inherit target; } {
      furnish = {
        files = [
          {
            source = throw "furnish workload forced an opaque file source";
            destination = ".ordinary";
          }
        ];
        links = [
          {
            source = "/external";
            inherit names;
            destinations = [
              ".a"
              ".b"
            ];
          }
        ];
      };
    }) args
  );

  compile =
    map
      (entry: {
        inherit (entry.filesystemIdentity) destination;
        inherit (entry) target executor;
      })
      (furnish.compile {
        inherit declarations;
        executors = [ executor ];
        provider = furnish.core.offProvider;
      }).manifestData;

  index = builtins.attrNames (
    furnish.core.buildHostIndex {
      inherit declarations;
      principals = [
        {
          authority = {
            scope = "user";
            identity = "user";
          };
          ctx = throw "furnish workload forced the index context";
        }
      ];
      provider = furnish.core.offProvider;
    }
  );
}
