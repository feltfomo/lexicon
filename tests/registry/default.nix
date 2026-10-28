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

  inaccessibleFleet = registry {
    root = ../..;
    runtimeRoot = null;
    den = throw "registry root forced the fleet input";
    hosts = { };
    users = { };
  };

  invalidFleet = registry {
    root = ../..;
    runtimeRoot = null;
    hosts.missingSystem = { };
    users = { };
  };

  identified = registry {
    root = ../..;
    runtimeRoot = null;
    defaultSystem = "x86_64-linux";
    hosts = {
      alpha.aliases = [ "first" ];
      beta = { };
    };
    users = {
      zed = {
        id = "account/zed";
        aliases = [ "last" ];
        hosts = [ "alpha" ];
      };
      amy.hosts = [ "alpha" ];
      nobody = { };
    };
  };

  names = records: map (record: record.name) records;

  diagnosticFleet = import ../../src/registry.nix {
    inherit lib axiom;
    krisis = krisis // {
      mkReporter = options: (krisis.mkReporter options) // { failOne = diagnostic: diagnostic; };
    };
    root = ../..;
    runtimeRoot = null;
    defaultSystem = "x86_64-linux";
    hosts.alpha = { };
    users.amy = { };
  };

  tests = {
    "test root does not demand fleet" = {
      expr = inaccessibleFleet.root;
      expected = ../..;
    };
    "test root does not validate tables" = {
      expr = invalidFleet.root;
      expected = ../..;
    };
    "test check validates complete tables" = {
      expr = invalidFleet.check;
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/host-system-missing\\] hosts\\.missingSystem: host 'missingSystem' has no system";
    };
    "test check reports every hostless host instead of stopping at the first" = {
      expr =
        (registry {
          root = ../..;
          runtimeRoot = null;
          hosts = {
            zulu = { };
            alpha = { };
          };
          users = { };
        }).check;
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 2 error\\(s\\)\n\\[registry/host-system-missing\\] hosts\\.alpha: [^\n]*\n[^\n]*\n\\[registry/host-system-missing\\] hosts\\.zulu: ";
    };
    "test empty system query keeps selector lazy" = {
      expr = empty.forSystem (throw "empty system query forced its selector");
      expected = [ ];
    };
    "test empty membership query keeps host lazy" = {
      expr =
        empty.usersOn (throw "empty membership query forced its host") == [ ]
        && diagnosticFleet.usersOn (throw "known-empty membership query forced its host") == [ ];
      expected = true;
    };
    "test non string system query is empty" = {
      expr = identified.forSystem null;
      expected = [ ];
    };
    "test user id lookup" = {
      expr = (identified.user "account/zed").name;
      expected = "zed";
    };
    "test users on alias preserves name order" = {
      expr = names (identified.usersOn "first");
      expected = [
        "amy"
        "zed"
      ];
    };
    "test users on known empty host" = {
      expr = identified.usersOn "beta";
      expected = [ ];
    };
    "test hosts for known empty user" = {
      expr = identified.hostsFor "nobody";
      expected = [ ];
    };
    "test unknown system has no hosts" = {
      expr = identified.forSystem "unknown-system";
      expected = [ ];
    };
    "test system query preserves name order" = {
      expr = names (identified.forSystem "x86_64-linux");
      expected = [
        "alpha"
        "beta"
      ];
    };
    "test home lookup accepts aliases and id" = {
      expr = identified.homeFor {
        host = "first";
        user = "account/zed";
      };
      expected = "/home/zed";
    };
    "test membership rejects known empty host" = {
      expr = identified.homeFor {
        host = "beta";
        user = "last";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-user\\] user 'zed' is not registered on host 'beta'";
    };
    "test unknown host diagnostic retains public projection" = {
      expr =
        let
          diagnostic = diagnosticFleet.host "alph";
        in
        diagnostic.code == "registry/unknown-host"
        && diagnostic.severity == "error"
        && diagnostic.message == "'alph' is not a registered host"
        && diagnostic.primary.label == "registry"
        && diagnostic.help == "did you mean 'alpha'?";
      expected = true;
    };
    "test membership diagnostic retains public projection" = {
      expr =
        let
          diagnostic = diagnosticFleet.homeFor {
            host = "alpha";
            user = "amy";
          };
        in
        diagnostic.code == "registry/unknown-user"
        && diagnostic.message == "user 'amy' is not registered on host 'alpha'"
        && diagnostic.help == "add 'alpha' to users.amy.hosts";
      expected = true;
    };
    "test roots stay distinct" = {
      expr = fleet.root == ../.. && fleet.runtimeRoot == "/etc/my-config";
      expected = true;
    };
    "test canonical ids" = {
      expr = fleet.hosts.khion.id == "x86_64-linux/khion" && fleet.hosts.pi.id == "aarch64-linux/pi";
      expected = true;
    };
    "test default system applies" = {
      expr = fleet.hosts.lumi.system;
      expected = "x86_64-linux";
    };
    "test declared system wins" = {
      expr = fleet.hosts.pi.system;
      expected = "aarch64-linux";
    };
    "test systems sorted" = {
      expr = fleet.systems;
      expected = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
    "test dimension default applies" = {
      expr = fleet.hosts.khion.dimensions.site;
      expected = "home";
    };
    "test dimension value wins" = {
      expr = fleet.hosts.lumi.dimensions.site;
      expected = "colo";
    };
    "test membership from top level" = {
      expr = fleet.users.feltfomo.hosts;
      expected = [
        "khion"
        "lumi"
      ];
    };
    "test membership from host block" = {
      expr = fleet.users.grandpa.hosts;
      expected = [ "lumi" ];
    };
    "test per host home" = {
      expr = fleet.homeFor {
        host = "lumi";
        user = "feltfomo";
      };
      expected = "/srv/feltfomo";
    };
    "test default home" = {
      expr = fleet.homeFor {
        host = "khion";
        user = "feltfomo";
      };
      expected = "/home/feltfomo";
    };
    "test host block home" = {
      expr = fleet.users.grandpa.homeByHost.lumi;
      expected = "/srv/grandpa";
    };
    "test alias lookup" = {
      expr = fleet.host "desktop";
      expected = fleet.hosts.khion;
    };
    "test user alias lookup" = {
      expr = (fleet.user "quiet").name;
      expected = "feltfomo";
    };
    "test membership queries" = {
      expr =
        names (fleet.usersOn "lumi") == [
          "feltfomo"
          "grandpa"
        ]
        && names (fleet.hostsFor "grandpa") == [ "lumi" ];
      expected = true;
    };
    "test dimension query" = {
      expr = names (fleet.hostsWhere { role = "server"; });
      expected = [
        "lumi"
        "pi"
      ];
    };
    "test system query" = {
      expr = names (fleet.forSystem "aarch64-linux");
      expected = [ "pi" ];
    };
    "test selected context" = {
      expr = selected.host.name == "khion" && selected.user.name == "feltfomo";
      expected = true;
    };
    "test knows without throwing" = {
      expr = fleet.knows.host "khion" && !(fleet.knows.host "khionn");
      expected = true;
    };
    "test everything checks" = {
      expr = fleet.check;
      expected = true;
    };
    "test summary is plain data" = {
      expr = fleet.summary;
      expected = {
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
    };
    "test native origin" = {
      expr = fleet.hosts.khion.origin;
      expected = "lexicon";
    };

    "test den inventory" = {
      expr =
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
      expected = true;
    };
    "test den origin" = {
      expr = inherited.hosts.khion.origin;
      expected = "den";
    };
    "test den homes default" = {
      expr = inherited.users.grandpa.homeByHost.lumi;
      expected = "/home/grandpa";
    };
    "test den dimensions" = {
      expr = inherited.hosts.lumi.dimensions.role;
      expected = "server";
    };

    "test layer merges" = {
      expr =
        layered.hosts.khion.origin == "both"
        &&
          layered.hosts.khion.aliases == [
            "khion"
            "desk"
          ]
        && layered.hosts.khion.dimensions.role == "desktop";
      expected = true;
    };
    "test layer adds" = {
      expr = layered.hosts.buildbox.origin;
      expected = "lexicon";
    };
    "test exclusion removes" = {
      expr = !(layered.hosts ? pi) && !(layered.knows.host "pi");
      expected = true;
    };
    "test exclusion stays unavailable" = {
      expr = layered.host "pi";
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/host-excluded\\] host 'pi' is excluded from this registry";
    };

    "test empty registry" = {
      expr = empty.summary.hosts == [ ] && empty.summary.users == [ ] && empty.systems == [ ];
      expected = true;
    };

    "test rejects missing users" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        hosts = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/users-missing\\] users: users is required";
    };
    "test rejects unknown field" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        hostz = { };
        hosts = { };
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/declaration-field\\] registry: unknown declaration field 'hostz'";
    };
    "test rejects string root" = {
      expr = registry {
        root = "/tmp/config";
        runtimeRoot = null;
        hosts = { };
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/root\\] root: root must be a Nix path";
    };
    "test rejects host without system" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        hosts.khion = { };
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/host-system-missing\\] hosts\\.khion: host 'khion' has no system";
    };
    "test rejects unknown dimension" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        dimensions.role.values = [ "desktop" ];
        hosts.khion.dimensions.rol = "desktop";
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-dimension\\] hosts\\.khion: host 'khion' sets undeclared dimension 'rol'";
    };
    "test rejects undeclared dimension value" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        dimensions.role.values = [ "desktop" ];
        hosts.khion.dimensions.role = "laptop";
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/dimension-value\\] hosts\\.khion: host 'khion' sets dimension 'role' to 'laptop', which is not a declare";
    };
    "test rejects missing required dimension" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        dimensions.role = {
          values = [ "desktop" ];
          required = true;
        };
        hosts.khion = { };
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/dimension-required\\] hosts\\.khion: host 'khion' is missing required dimension 'role'";
    };
    "test rejects unknown user host" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        hosts.khion = { };
        users.river.hosts = [ "khionn" ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-host\\] users\\.river: user 'river' lives on unregistered host 'khionn'";
    };
    "test rejects stray exclusion" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        hosts.ghost = null;
        users = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/exclude-no-match\\] hosts\\.ghost: hosts\\.ghost = null excludes a host no layer declares";
    };
    "test rejects unknown host lookup" = {
      expr = fleet.host "khionn";
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-host\\] registry: 'khionn' is not a registered host";
    };
    "test rejects unknown user lookup" = {
      expr = fleet.user "nobody";
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-user\\] registry: 'nobody' is not a registered user";
    };
    "test rejects user off host" = {
      expr = fleet.context {
        host = "pi";
        user = "quiet";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/unknown-user\\] user 'feltfomo' is not registered on host 'pi'";
    };
    "test rejects conflicting user ids" = {
      expr = registry {
        root = ../..;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        hosts.khion = { };
        users = {
          river.id = "operator";
          brook.id = "operator";
        };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/user-id-conflict\\] user id 'operator' belongs to more than one registered user";
    };
    "test rejects alias conflicts" = {
      expr = registry {
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
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "registry: 1 error\\(s\\)\n\\s*\\[registry/alias-conflict\\] host name or alias 'box' is registered more than once";
    };
  };
in
{
  inherit
    fleet
    inherited
    layered
    tests
    ;
}
