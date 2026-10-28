{
  lib,
  pkgs,
  axiom,
  krisis,
  lexicon,
}:
let
  owners = import ../../src/lexicon/resources.nix { inherit lib axiom krisis; };
  extension = { definitions, ... }: {
    name = "resource-effects";
    blocks = [
      {
        name = "opaqueFiles";
        scope = "user";
        outputs = [ "resources" ];
        node = definitions.collection {
          item = definitions.record {
            fields = {
              payload = { };
              destination = { };
            };
          };
        };
        lower = { value, origins, ... }: {
          resources = lib.imap0 (i: entry: {
            kind = "file";
            origin = (builtins.elemAt origins i).self;
            value = {
              source = entry.payload;
              inherit (entry) destination;
            };
          }) value;
        };
      }
      {
        name = "inventory";
        scope = "user";
        outputs = [ "resources" ];
        node = definitions.record {
          fields = owners.schemas.directory;
          prepare =
            args:
            let
              prepared = owners.prepareDirectory args;
            in
            prepared // { inventory = builtins.trace "resource-effects inventory" prepared.inventory; };
        };
        lower =
          {
            value,
            origins,
            prepared,
            ...
          }:
          {
            resources = [
              {
                kind = "directory";
                inherit value;
                origin = origins.self;
                prepared = prepared.self;
              }
            ];
          };
      }
    ];
  };
  api = lexicon.lib.lexicon.configure { extensions = [ extension ]; };
  inherit (api) ownerships;
  roster = ownerships.toRoster [
    (ownerships.define.host "host" { system = "x86_64-linux"; })
    (ownerships.define.host "away" { system = "x86_64-linux"; })
    (ownerships.define.user "alice" { hosts = [ "host" ]; })
    (ownerships.define.user "bob" { hosts = [ "host" ]; })
  ];
  authored = api.forRoster { inherit roster; } {
    opaqueFiles = [
      {
        hosts = [ "away" ];
        payload = throw "inactive resource payload";
        destination = throw "inactive destination";
      }
      {
        payload.secret = throw "selected resource poison";
        destination = ".opaque";
      }
    ];
    inventory = {
      source = ../program/fixtures/prunable;
      destination = ".inventory";
      exclude = [ "nested" ];
    };
  };
  entries =
    user:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon)
        (authored.nixos {
          inherit lib pkgs;
          host = {
            name = "host";
            system = "x86_64-linux";
          };
          user.name = user;
          config = {
            networking.hostName = "host";
            lexicon.furnish.declarations = [ ];
          };
        }).imports
    )).lexicon.furnish.declarations;
  furnish = lexicon.lib.furnish {
    resolve = throw "unexpected resolver";
    resolveSystem = throw "unexpected resolver";
  };
  executor = {
    identity = "resource-effects/executor";
    priority = 0;
    enabled = true;
    protocolVersion = 1;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize = entry: {
      target = {
        kind = "external";
        path = "/external/${baseNameOf entry.filesystemIdentity.destination}";
      };
      cleanupStrategy = "exact-symlink-target";
      selfHealStrategy = "exact-symlink-target";
    };
  };
  compiled = furnish.compile {
    declarations = entries "alice";
    executors = [ executor ];
    provider = furnish.core.offProvider;
  };
  probe = {
    first = map (entry: {
      inherit (entry) destination;
      principal = entry.authority.identity;
    }) (entries "alice");
    second = map (entry: {
      inherit (entry) destination;
      principal = entry.authority.identity;
    }) (entries "bob");
  };
  directoryPlan = {
    kind = "directory";
    origin = [
      "furnish"
      "directories"
      0
    ];
    value = {
      source = ../program/fixtures/prunable;
      destination = ".local-tree";
    };
  };
  themePlan = {
    kind = "theme";
    origin = [ "theme" ];
    value = {
      renderer = "noctalia";
      blockId = "local";
      entry = {
        source = ../program/fixtures/prunable/root.nix;
        output = ".theme-output";
      };
    };
  };
  tests = {
    "test directory theme source suppression stays declaration local" = {
      expr =
        map (entry: entry.dest)
          (owners.compose [
            directoryPlan
            themePlan
          ]).files == [ ".local-tree/nested/inner.toml" ]
        &&
          map (entry: entry.dest) (owners.compose [ directoryPlan ]).files == [
            ".local-tree/nested/inner.toml"
            ".local-tree/root.nix"
          ];
      expected = true;
    };
    "test selected resource poison survives complete public transport" = {
      expr =
        builtins.attrNames (builtins.head (entries "alice")).source.value == [ "secret" ]
        &&
          map (entry: entry.target.path) compiled.manifestData == [
            "/external/root.nix"
            "/external/.opaque"
          ];
      expected = true;
    };
    "test selected resource principals and shared preparation survive" = {
      expr =
        map (entry: entry.principal) probe.first == [
          "alice"
          "alice"
        ]
        &&
          map (entry: entry.principal) probe.second == [
            "bob"
            "bob"
          ];
      expected = true;
    };
  };
in
{
  inherit tests probe;
}
