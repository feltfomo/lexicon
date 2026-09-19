{
  lib,
  axiom,
  krisis,
}:
let
  registry =
    declaration:
    import ../../src/registry.nix (
      {
        inherit lib axiom krisis;
      }
      // declaration
    );
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  fleet = registry {
    root = ../..;
    runtimeRoot = "/etc/my-config";
    defaultSystem = "x86_64-linux";
    dimensions = {
      role = {
        values = [
          "desktop"
          "server"
        ];
        required = true;
      };
      site = {
        values = [
          "home"
          "colo"
        ];
        default = "home";
      };
    };
    hosts = {
      khion = {
        aliases = [
          "khion"
          "desktop"
        ];
        dimensions.role = "desktop";
      };
      lumi = {
        dimensions = {
          role = "server";
          site = "colo";
        };
        users.grandpa.home = "/srv/grandpa";
      };
      pi = {
        system = "aarch64-linux";
        dimensions.role = "server";
        users.operator = { };
      };
    };
    users.feltfomo = {
      aliases = [
        "feltfomo"
        "quiet"
      ];
      hosts = [
        "khion"
        "lumi"
      ];
      on.lumi.home = "/srv/feltfomo";
    };
  };

  # every den user value throws, so inheriting a fleet must never force one
  den = {
    hosts = {
      x86_64-linux = {
        khion = {
          dimensions.role = "desktop";
          users.feltfomo = throw "den user values must stay lazy";
        };
        lumi = {
          dimensions.role = "server";
          users = {
            feltfomo = throw "den user values must stay lazy";
            grandpa = throw "den user values must stay lazy";
          };
        };
      };
      aarch64-linux.pi.users.operator = throw "den user values must stay lazy";
    };
    lib = throw "den.lib must stay lazy for fleet inheritance";
  };

  inherited = registry {
    inherit den;
    root = ../..;
    runtimeRoot = null;
    hosts = { };
    users = { };
  };

  layered = registry {
    inherit den;
    root = ../..;
    runtimeRoot = null;
    defaultSystem = "x86_64-linux";
    hosts = {
      # den already declares khion; lexicon only adds to it
      khion.aliases = [
        "khion"
        "desk"
      ];
      # a host den knows nothing about
      buildbox = { };
      # and one den has that this configuration does not register
      pi = null;
    };
    users.river.hosts = [ "buildbox" ];
  };

  empty = registry {
    root = ../..;
    runtimeRoot = null;
    hosts = { };
    users = { };
  };

  selected = fleet.context {
    host = "desktop";
    user = "quiet";
  };

  names = records: map (record: record.name) records;

  checks = {
    rootsStayDistinct = fleet.root == ../.. && fleet.runtimeRoot == "/etc/my-config";
    canonicalIds =
      fleet.hosts.khion.id == "x86_64-linux/khion" && fleet.hosts.pi.id == "aarch64-linux/pi";
    defaultSystemApplies = fleet.hosts.lumi.system == "x86_64-linux";
    declaredSystemWins = fleet.hosts.pi.system == "aarch64-linux";
    systemsSorted =
      fleet.systems == [
        "aarch64-linux"
        "x86_64-linux"
      ];
    dimensionDefaultApplies = fleet.hosts.khion.dimensions.site == "home";
    dimensionValueWins = fleet.hosts.lumi.dimensions.site == "colo";
    membershipFromTopLevel =
      fleet.users.feltfomo.hosts == [
        "khion"
        "lumi"
      ];
    membershipFromHostBlock = fleet.users.grandpa.hosts == [ "lumi" ];
    perHostHome =
      fleet.homeFor {
        host = "lumi";
        user = "feltfomo";
      } == "/srv/feltfomo";
    defaultHome =
      fleet.homeFor {
        host = "khion";
        user = "feltfomo";
      } == "/home/feltfomo";
    hostBlockHome = fleet.users.grandpa.homeByHost.lumi == "/srv/grandpa";
    aliasLookup = fleet.host "desktop" == fleet.hosts.khion;
    userAliasLookup = (fleet.user "quiet").name == "feltfomo";
    membershipQueries =
      names (fleet.usersOn "lumi") == [
        "feltfomo"
        "grandpa"
      ]
      && names (fleet.hostsFor "grandpa") == [ "lumi" ];
    dimensionQuery =
      names (fleet.hostsWhere { role = "server"; }) == [
        "lumi"
        "pi"
      ];
    systemQuery = names (fleet.forSystem "aarch64-linux") == [ "pi" ];
    selectedContext = selected.host.name == "khion" && selected.user.name == "feltfomo";
    knowsWithoutThrowing = fleet.knows.host "khion" && !(fleet.knows.host "khionn");
    everythingChecks = fleet.check;
    summaryIsPlainData =
      fleet.summary == {
        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];
        hosts = [
          "khion"
          "lumi"
          "pi"
        ];
        users = [
          "feltfomo"
          "grandpa"
          "operator"
        ];
      };
    nativeOrigin = fleet.hosts.khion.origin == "lexicon";

    denInventory =
      inherited.summary.hosts == [
        "khion"
        "lumi"
        "pi"
      ]
      &&
        inherited.users.feltfomo.hosts == [
          "khion"
          "lumi"
        ];
    denOrigin = inherited.hosts.khion.origin == "den";
    denHomesDefault = inherited.users.grandpa.homeByHost.lumi == "/home/grandpa";
    denDimensions = inherited.hosts.lumi.dimensions.role == "server";

    layerMerges =
      layered.hosts.khion.origin == "both"
      &&
        layered.hosts.khion.aliases == [
          "khion"
          "desk"
        ]
      && layered.hosts.khion.dimensions.role == "desktop";
    layerAdds = layered.hosts.buildbox.origin == "lexicon";
    exclusionRemoves = !(layered.hosts ? pi) && !(layered.knows.host "pi");
    exclusionStaysUnavailable = fails (layered.host "pi");

    emptyRegistry = empty.summary.hosts == [ ] && empty.summary.users == [ ] && empty.systems == [ ];

    rejectsMissingUsers = fails (registry {
      root = ../..;
      runtimeRoot = null;
      hosts = { };
    });
    rejectsUnknownField = fails (registry {
      root = ../..;
      runtimeRoot = null;
      hostz = { };
      hosts = { };
      users = { };
    });
    rejectsStringRoot = fails (registry {
      root = "/tmp/config";
      runtimeRoot = null;
      hosts = { };
      users = { };
    });
    rejectsHostWithoutSystem = fails (registry {
      root = ../..;
      runtimeRoot = null;
      hosts.khion = { };
      users = { };
    });
    rejectsUnknownDimension = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      dimensions.role.values = [ "desktop" ];
      hosts.khion.dimensions.rol = "desktop";
      users = { };
    });
    rejectsUndeclaredDimensionValue = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      dimensions.role.values = [ "desktop" ];
      hosts.khion.dimensions.role = "laptop";
      users = { };
    });
    rejectsMissingRequiredDimension = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      dimensions.role = {
        values = [ "desktop" ];
        required = true;
      };
      hosts.khion = { };
      users = { };
    });
    rejectsUnknownUserHost = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      hosts.khion = { };
      users.river.hosts = [ "khionn" ];
    });
    rejectsStrayExclusion = fails (registry {
      root = ../..;
      runtimeRoot = null;
      hosts.ghost = null;
      users = { };
    });
    rejectsUnknownHostLookup = fails (fleet.host "khionn");
    rejectsUnknownUserLookup = fails (fleet.user "nobody");
    rejectsUserOffHost = fails (
      fleet.context {
        host = "pi";
        user = "quiet";
      }
    );
    rejectsConflictingUserIds = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      hosts.khion = { };
      users = {
        river.id = "operator";
        brook.id = "operator";
      };
    });
    rejectsAliasConflicts = fails (registry {
      root = ../..;
      runtimeRoot = null;
      defaultSystem = "x86_64-linux";
      hosts = {
        khion.aliases = [
          "khion"
          "box"
        ];
        lumi.aliases = [
          "lumi"
          "box"
        ];
      };
      users = { };
    });
  };
in
{
  inherit
    fleet
    inherited
    layered
    checks
    ;
  ok = builtins.all (value: value) (builtins.attrValues checks);
}
