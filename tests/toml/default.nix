{
  pkgs,
  lexicon,
  nixpkgs,
}:
let
  inherit (pkgs) lib;
  toml = lexicon.lib.toml { inherit pkgs; };
  generated = toml.generate "all-values.toml" {
    "" = "empty key";
    "a.b" = "quoted key";
    __lexiconToml = "ordinary application key";
    integer = 9223372036854775807;
    minimum = -9223372036854775807 - 1;
    float = 1.0;
    plainTables = [
      { x = 1; }
      { x = 2; }
    ];
    precise = 1.2345678901234567;
    context = "${pkgs.coreutils}/bin/true";
    values = map toml.literal [
      "inf"
      "-inf"
      "nan"
      "-0.0"
      "1979-05-27T07:32:00Z"
      "1979-05-27T07:32:00"
      "1979-05-27"
      "07:32:00"
      "'''literal\nstring'''"
    ];
    nested = [
      [
        1
        "two"
        true
      ]
      [ ]
    ];
    empty = { };
    emptyTables = toml.tables [ ];
    inline = toml.inline {
      foo = "bar";
      empty = { };
      tables = toml.tables [
        {
          x = 1;
          nested = toml.tables [ { y = true; } ];
        }
      ];
    };
    servers = toml.tables [
      {
        name = "one";
        child = toml.tables [ { enabled = true; } ];
      }
    ];
  };
  retained = toml.merge "retained.toml" {
    sources = [
      (toml.document "# retained comment\nstamp = 1979-05-27T07:32:00Z\nnegative = -0.0\n")
      { hello = "world"; }
    ];
  };
  conflict = toml.merge "replacement.toml" {
    conflict = "last";
    sources = [
      { array = [ 1 ]; }
      { array = [ 2 ]; }
    ];
  };
  program = lexicon.lib.programDirect {
    target = {
      host = {
        name = "fixture";
        system = pkgs.stdenv.hostPlatform.system;
      };
      user = {
        name = "tester";
        home = "/build/home";
      };
    };
  };
  aspect = program {
    theme = {
      id = "test";
      output = ".config/app/config.toml";
      merge = {
        format = "toml";
        base = {
          operational = true;
        };
      };
      renderers = {
        noctalia = {
          source = ./palette.toml;
          subId = "one";
        };
        dms.source = ./palette.toml;
        caelestia.source = ./palette.toml;
      };
    };
  };
  host = nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      aspect.nixos
      (_: {
        networking.hostName = "fixture";
        system.stateVersion = "26.05";
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        boot.loader.grub.enable = false;
        lexicon.furnish.enable = true;
        users.users.tester = {
          isNormalUser = true;
          home = "/build/home";
        };
      })
    ];
  };
  cfg = host.config;
  services = lib.filterAttrs (name: _: lib.hasPrefix "lexicon-toml-" name) cfg.systemd.services;
  service = builtins.head (builtins.attrValues services);
  manifests = cfg.lexicon.furnish.manifestData;
  sourceFor =
    suffix:
    (builtins.head (
      builtins.filter (e: lib.hasSuffix suffix e.filesystemIdentity.destination) manifests
    )).target.path;
  example = (import ../../examples/toml/flake.nix).outputs { inherit lexicon nixpkgs; };
  exampleServices = lib.filterAttrs (
    name: _: lib.hasPrefix "lexicon-toml-" name
  ) example.nixosConfigurations.demo.config.systemd.services;
  boundaries = import ./boundaries.nix { inherit pkgs lexicon nixpkgs; };
  fixture = pkgs.writeText "composition-fixture.json" (
    builtins.toJSON {
      inherit boundaries;
      example =
        assert builtins.length (builtins.attrNames exampleServices) == 1;
        example.packages.x86_64-linux.default;
      noctalia = sourceFor "/.config/noctalia/test.toml";
      matugen = sourceFor "/.config/matugen/config.toml";
      caelestia = sourceFor "/.config/caelestia/theme-hooks/test";
      shell = "${pkgs.bash}/bin/bash";
      descriptor = sourceFor "/.config/lexicon/toml/${
        builtins.substring 0 32 (builtins.hashString "sha256" ".config/app/config.toml")
      }.json";
      unit = cfg.systemd.units."${builtins.head (builtins.attrNames services)}.service".text;
      inherit (service) restartTriggers after requires;
      inherit (service.serviceConfig) ExecStart User;
      assertions = map (a: {
        inherit (a) assertion;
        message = if a.assertion then "passed" else a.message;
      }) (builtins.filter (a: !a.assertion) cfg.assertions);
      destinations = map (e: e.filesystemIdentity.destination) manifests;
    }
  );
  python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
in
pkgs.runCommand "toml-composition-tests"
  {
    nativeBuildInputs = [
      python
      pkgs.bash
    ];
  }
  ''
    set -euo pipefail
    export LEXICON_TOML=${../../src/toml/runtime.py}
    export TOML_CLI=${toml.package}/bin/lexicon-toml
    python ${./test.py} ${generated} ${retained} ${conflict} ${fixture}
    touch "$out"
  ''
