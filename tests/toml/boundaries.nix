{
  pkgs,
  lexicon,
  nixpkgs,
}:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  toml = lexicon.lib.toml { inherit pkgs; };
  programFor =
    user: home:
    lexicon.lib.programDirect {
      target = {
        host = {
          name = "fixture";
          inherit system;
        };
        user = {
          name = user;
          inherit home;
        };
      };
    };
  theme = id: output: base: {
    theme = {
      inherit id output;
      merge = {
        format = "toml";
        inherit base;
      };
      renderers.noctalia.source = ./palette.toml;
    };
  };
  moduleFor =
    user: home: spec:
    ((programFor user home) spec).nixos;
  host =
    modules:
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = modules ++ [
        {
          networking.hostName = "fixture";
          system.stateVersion = "26.05";
          boot.isContainer = true;
          lexicon.furnish.enable = true;
          users.users = {
            tester = {
              isNormalUser = true;
              home = "/build/tester";
            };
            other = {
              isNormalUser = true;
              home = "/build/other";
            };
          };
        }
      ];
    }).config;
  primary = moduleFor "tester" "/build/tester" (
    theme "primary" ".config/app/config.toml" { enabled = true; }
  );
  invalid =
    modules:
    builtins.any (a: !a.assertion && lib.hasPrefix "theme.merge:" a.message)
      (host ([ primary ] ++ modules)).assertions;
  separated = host [
    primary
    (moduleFor "other" "/build/other" (
      theme "secondary" ".config/app/config.toml" { enabled = false; }
    ))
  ];
  services = lib.filterAttrs (name: _: lib.hasPrefix "lexicon-toml-" name) separated.systemd.services;
  declarations = separated.lexicon.furnish.declarations;
  sourceFor =
    user:
    (builtins.head (
      builtins.filter (
        d:
        d.authority.identity == user && d.destination == ".config/noctalia/primary.toml"
        || d.authority.identity == user && d.destination == ".config/noctalia/secondary.toml"
      ) declarations
    )).source.value;
  disabled = host [
    primary
    { lexicon.furnish.enable = lib.mkForce false; }
  ];
  nativeHook = moduleFor "tester" "/build/native" {
    theme = (theme "native" ".config/app/config.toml" { }).theme // {
      native.post_hook = "printf native-hook";
    };
  };
  nativeConfig = host [ nativeHook ];
  nativeEntry = builtins.head nativeConfig.lexicon.theme.composition.entries;
  explicitHook = moduleFor "tester" "/build/explicit" {
    theme = (theme "explicit" ".config/app/config.toml" { }).theme // {
      native.post_hook = "ignored-native";
      reload = "printf explicit-hook";
    };
  };
  explicitConfig = host [ explicitHook ];
  fails = value: !(builtins.tryEval (builtins.deepSeq value.drvPath value.drvPath)).success;
  malformed = (toml.document "a=1\n") // {
    typo = true;
  };
in
assert invalid [
  (moduleFor "tester" "/build/tester" {
    files = [
      {
        dest = ".config/app/config.toml";
        src = ./palette.toml;
      }
    ];
  })
];
assert invalid [
  (moduleFor "tester" "/build/tester" {
    links = [
      {
        dest = ".config/app";
        target = "/external/path";
      }
    ];
  })
];
assert invalid [
  (moduleFor "tester" "/build/tester" {
    theme = {
      id = "ordinary";
      output = ".config/app/config.toml/child";
      renderers.noctalia.source = ./palette.toml;
    };
  })
];
assert invalid [
  (moduleFor "tester" "/build/tester" (theme "other" ".config/app/config.toml/child" { }))
];
assert invalid [
  (moduleFor "tester" "/build/tester" (theme "other" ".config/app/config.toml" { enabled = false; }))
];
assert invalid [
  (moduleFor "tester" "/build/tester" (theme "second" ".config/app/config.toml" { enabled = true; }))
];
assert invalid [
  (moduleFor "other" "/build/other/../tester" (
    theme "alias" ".config/app/config.toml" { enabled = true; }
  ))
];
assert
  (lib.filterAttrs (name: _: lib.hasPrefix "lexicon-toml-" name) disabled.systemd.services) == { };
assert disabled.lexicon.theme.composition.entries != [ ];
assert nativeEntry.originalReload == "printf native-hook";
assert
  (builtins.head explicitConfig.lexicon.theme.composition.entries).originalReload
  == "printf explicit-hook";
assert !(builtins.tryEval (builtins.deepSeq (toml.source "invalid" null) true)).success;
assert fails (toml.merge "empty.toml" { sources = [ ]; });
assert invalid [
  (moduleFor "tester" "/build/tester" (theme "reserved" ".local/state/lexicon/toml" { }))
];
assert invalid [
  (moduleFor "tester" "/build/tester" (theme "reserved" ".local/state/lexicon" { }))
];
assert invalid [
  (moduleFor "tester" "/build/tester" {
    files = [
      {
        dest = ".local/state/lexicon/toml/private";
        src = ./palette.toml;
      }
    ];
  })
];
assert invalid [
  (moduleFor "tester" "/build/tester" {
    links = [
      {
        dest = ".local/state/lexicon/toml";
        target = "/external/path";
      }
    ];
  })
];
assert invalid [
  (moduleFor "tester" "/build/tester" {
    theme = {
      id = "reserved-theme";
      output = ".local/state/lexicon/toml/palette.toml";
      renderers.noctalia.source = ./palette.toml;
    };
  })
];
assert builtins.length (builtins.attrNames services) == 2;
assert fails (toml.generate "invalid.toml" { missing = null; });
assert fails (toml.generate "invalid.toml" malformed);
assert fails (toml.merge "invalid.toml" { sources = [ malformed ]; });
{
  other = sourceFor "other";
  tester = sourceFor "tester";
}
