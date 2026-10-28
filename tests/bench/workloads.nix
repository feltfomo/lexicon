# every subsystem workload's projection against a value built here from the
# workload's size alone. a comparison only shows that both sides agree, so this
# is what shows a workload measures what its name says. fleet.den fetches Den
# and Home Manager, which the unit sandbox can't, so it isn't here
{ lib, lexicon }:
let
  catalog = import ../../bench/workloads;
  size = 4;
  indices = lib.range 0 (size - 1);
  names = map (index: "item${toString index}") indices;
  everyName = lib.genAttrs names (_: true);

  project =
    name:
    catalog.project {
      project = lexicon;
      system = "x86_64-linux";
      inherit size name;
    };

  # one case per workload, named for it
  cases = lib.mapAttrs' (
    name: expected:
    lib.nameValuePair "test ${name} projects its independent value" {
      expr = (expected.project or lib.id) (project name);
      expected = expected.value;
    }
  );

  # declaration entries as the compiler workloads author them, with a default,
  # metadata and preparation per entry
  home =
    { origin, context }:
    {
      entries = map (index: {
        n = index + 1;
        defaulted = 7;
        tag = index + 10;
        origin = origin index;
        prepared = index;
      }) indices;
      inherit context;
      output = "homeManager";
    };
  within = field: index: [
    "sample"
    field
    (index + 1)
  ];
  nested =
    index:
    [ "sample" ]
    ++ lib.concatLists (
      lib.replicate index [
        "next"
        1
      ]
    );

  directory =
    principal:
    map (name: {
      destination = ".tree/${name}/default.nix";
      representation = "writable";
      inherit principal;
    }) names;

  contexts = map (name: "fleet/${name}/user") names;
  leafKey = host: child: "leaf-${toString (2 * host + child)}";
  rejection =
    host: other: child:
    lib.optional (host != other) "host" ++ lib.optional (child == 1) "when";
  hostPairs = lib.concatMap (
    left: map (right: { inherit left right; }) (builtins.filter (right: left < right) indices)
  ) indices;
in
{
  tests = cases {
    "subsystem.ownerships.resolve".value.values = everyName;
    "subsystem.ownerships.fleet-resolve".value = map (name: { ${name} = true; }) names;
    "subsystem.ownerships.fleet-prepared".value = map (name: { ${name} = true; }) names;
    "subsystem.ownerships.fleet-custom".value.values = everyName;
    "subsystem.ownerships.fleet-trace".value = {
      value.values.item0 = true;
      leaves = lib.concatMap (
        host:
        map
          (child: {
            checks = 0;
            key = "0/${toString host}/${toString child}";
            rejectedBy = rejection 0 host child;
            selected = rejection 0 host child == [ ];
          })
          [
            0
            1
          ]
      ) indices;
      stages = {
        leaf = 3;
        tree = 0;
        survivors = 0;
      };
    };
    "subsystem.ownerships.fleet-matrix".value = {
      byContext = builtins.listToAttrs (
        map (host: {
          name = "fleet/item${toString host}/user";
          value = {
            hostName = "fleet/item${toString host}";
            userName = "user";
            inactive = lib.concatMap (
              other:
              lib.concatMap
                (
                  child:
                  lib.optional (rejection host other child != [ ]) {
                    key = leafKey other child;
                    rejectedBy = rejection host other child;
                  }
                )
                [
                  0
                  1
                ]
            ) indices;
            preMergePaths = [ "values" ];
            survivors = [ (leafKey host 0) ];
          };
        }) indices
      );
      hostDiffs = builtins.listToAttrs (
        map (pair: {
          name = "fleet/item${toString pair.left} -> fleet/item${toString pair.right}";
          value = {
            units = {
              leftOnly = [ (leafKey pair.left 0) ];
              rightOnly = [ (leafKey pair.right 0) ];
            };
            preMergePaths = {
              leftOnly = [ ];
              rightOnly = [ ];
            };
          };
        }) hostPairs
      );
      dead = 0;
      never = size;
      coverage = {
        units = builtins.listToAttrs (
          lib.concatMap (
            host:
            map
              (child: {
                name = leafKey host child;
                value = lib.optional (child == 0) (builtins.elemAt contexts host);
              })
              [
                0
                1
              ]
          ) indices
        );
        preMerge = {
          meaning = "top-level paths offered by surviving leaves before merge";
          paths.values = contexts;
        };
      };
    };

    "subsystem.registry.summary".value = {
      hosts = names;
      users = [ ];
      systems = [ "x86_64-linux" ];
    };
    "subsystem.registry.queries".value = map (name: {
      users = names;
      systems = names;
      hosts = names;
      home = "/home/${name}";
    }) names;

    "subsystem.declarations.native".value = [ { environment = everyName; } ];
    "subsystem.declarations.wide".value = home {
      origin = within "entries";
      context = 0;
    };
    "subsystem.declarations.dynamic".value = home {
      origin = within "entries";
      context = 0;
    };
    "subsystem.declarations.deep".value = home {
      origin = nested;
      context = 0;
    };
    "subsystem.declarations.prepared".value = map (
      context:
      home {
        origin = within "entries";
        inherit context;
      }
    ) indices;
    "subsystem.declarations.single".value = home {
      origin = within "hm";
      context = 0;
    };
    "subsystem.declarations.combined".value = {
      home = home {
        origin = within "hm";
        context = "home";
      };
      resources = map (index: {
        destination = ".sample/${toString (index + 1)}";
        source = "/external/${toString (index + 1)}";
      }) indices;
    };

    "subsystem.furnish.links".value = map (name: ".links/${name}") names;
    "subsystem.furnish.directory".value = directory "user";
    "subsystem.furnish.shared".value = map (index: directory "user${toString index}") indices;
    "subsystem.furnish.grouped".value = [
      ".ordinary"
    ]
    ++ map (name: ".a/${name}") names
    ++ map (name: ".b/${name}") names;
    "subsystem.furnish.compile".value = map (name: {
      destination = "/home/user/.files/${name}";
      target = {
        kind = "external";
        path = "/external/${name}";
      };
      executor = {
        identity = "component/executor";
        protocolVersion = 1;
      };
    }) names;
    "subsystem.furnish.index".value = map (name: "x86_64-linux/host:/home/user/.files/${name}") names;

    "subsystem.theme.matugen".value = {
      destinations =
        map (name: ".config/matugen/dms/templates/${name}/safe-render.nix") (lib.reverseList names)
        ++ [ ".config/matugen/config.toml" ];
      templates = lib.genAttrs names (name: {
        output_path = "/home/user/.output/${name}";
      });
    };

    # the document is read back, so the check is its content, not its spelling.
    # the text keeps the executable's context, which fromTOML refuses
    "subsystem.toml.generate" = {
      project = text: builtins.fromTOML (builtins.unsafeDiscardStringContext text);
      value = lib.genAttrs names (_: {
        count = 1;
        precise = 1.2345678901234567;
        executable = "coreutils/bin/true";
        values = [
          true
          "two"
          3
        ];
        spelling = 16;
      });
    };

    "subsystem.praxis.manifest" = {
      project = manifest: {
        inherit (manifest) version bash;
        commands = builtins.attrNames manifest.commands;
      };
      value = {
        version = 2;
        bash = "bash";
        commands = names;
      };
    };
    "subsystem.praxis.selected" = {
      project = manifest: {
        inherit (manifest) version;
        commands = builtins.attrNames manifest.commands;
        steps = map (step: step.command) manifest.commands.gate.steps;
        defaults = map (name: (builtins.head manifest.commands."ops.${name}".parameters).default) names;
      };
      value = {
        version = 2;
        commands = [ "gate" ] ++ map (name: "ops.${name}") names;
        steps = map (name: "ops.${name}") names;
        defaults = map (_: "7") names;
      };
    };
    "subsystem.praxis.diagnostics".value = {
      codes = lib.replicate (2 * size) "praxis/args-shape";
      paths = lib.replicate (2 * size) [ 0 ];
      summary = {
        total = 2 * size;
        hasErrors = true;
        byCode."praxis/args-shape" = 2 * size;
        bySeverity = {
          error = 2 * size;
          warning = 0;
          info = 0;
        };
      };
    };
  };
}
