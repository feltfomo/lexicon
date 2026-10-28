{
  lib,
  pkgs,
  krisis,
  axiom,
  lexicon,
}:
let
  target = {
    host = {
      name = "test";
      system = pkgs.stdenv.hostPlatform.system;
    };
    user = {
      name = "alice";
      home = "/srv/alice";
    };
  };
  program = lexicon.lib.programDirect { inherit target; };
  args = {
    inherit pkgs lib;
    config = {
      networking.hostName = "test";
      lexicon.furnish.declarations = [ { } ];
    };
  };
  declarations =
    spec:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon)
        ((program spec).nixos args).imports
    )).lexicon.furnish.declarations;
  link = {
    target = "/srv/alice/Projects/skills/subphase-orchestrator";
    dest = ".claude/skills/subphase-orchestrator";
  };
  selected = builtins.head (declarations {
    links = [ link ];
  });
  invalid =
    entry: !(builtins.tryEval (builtins.deepSeq (declarations { links = [ entry ]; }) true)).success;
  ownerships = lexicon.lib.ownerships { inherit lib krisis axiom; };
  roster = ownerships.toRoster [
    (ownerships.define.host "test" { inherit (target.host) system; })
    (ownerships.define.user "alice" { hosts = [ "test" ]; })
  ];
  ownedProgram = lexicon.lib.programOwnerships { inherit roster; };
  ownedDeclarations =
    spec:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon)
        ((ownedProgram spec).nixos (args // { inherit (target) host user; })).imports
    )).lexicon.furnish.declarations;
  selectedOwned = ownedDeclarations { links = [ (link // { users = [ "alice" ]; }) ]; };
  inactive = builtins.tryEval (
    builtins.deepSeq (ownedDeclarations {
      links = [
        {
          target = throw "forced an inactive external target";
          dest = "unused";
          when = _: false;
        }
      ];
    }) true
  );
  runtime = lib.evalModules {
    modules = [
      ({ lib, ... }: {
        options = {
          networking.hostName = lib.mkOption {
            type = lib.types.str;
            default = "test";
          };
          system = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          environment = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          systemd = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        };
        config.lexicon.furnish.declarations = [ selected ];
      })
      (lexicon.lib.furnishRuntime { })
    ];
    specialArgs = { inherit pkgs; };
  };
  compiled = builtins.head runtime.config.lexicon.furnish.manifestData;
  targets = import ../../src/furnish/target.nix { inherit lib; };
  furnish = lexicon.lib.furnish {
    resolve = _: _: throw "unexpected ownership lookup";
    resolveSystem = _: _: throw "unexpected ownership lookup";
  };
  executor = {
    identity = "furnish/native-symlink";
    priority = 0;
    enabled = true;
    protocolVersion = 1;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize = declaration: {
      target = targets.materialize declaration;
      cleanupStrategy = "exact-symlink-target";
      selfHealStrategy = "exact-symlink-target";
    };
  };
  duplicate =
    !(builtins.tryEval (
      builtins.deepSeq
        (furnish.compile {
          declarations = declarations {
            links = [ link ];
            files = [
              {
                src = ./links.nix;
                inherit (link) dest;
              }
            ];
          };
          executors = [ executor ];
          provider = furnish.core.offProvider;
        }).manifestData
        true
    )).success;
in
{
  "test external links use the selected home" = {
    expr = selected.managedRoot;
    expected = "/srv/alice";
  };
  "test owned external links select the current user" = {
    expr = builtins.length selectedOwned;
    expected = 1;
  };
  "test inactive external targets stay lazy" = {
    expr = inactive.success;
    expected = true;
  };
  "test external links remain literal" = {
    expr = selected.source;
    expected = {
      kind = "external";
      value = link.target;
    };
  };
  "test absent external targets compile without filesystem access" = {
    expr = compiled.target;
    expected = {
      kind = "external";
      path = link.target;
    };
  };
  "test external link manifests carry no source context" = {
    expr = builtins.getContext (builtins.toJSON compiled);
    expected = { };
  };
  "test external links emit the current manifest schema" = {
    expr = compiled.schemaVersion;
    expected = 3;
  };
  "test external links share file collision detection" = {
    expr = duplicate;
    expected = true;
  };
  "test external links reject relative and nonnormal targets" = {
    expr = builtins.all (path: invalid (link // { target = path; })) [
      "/srv//alice"
      "/srv/../alice"
      "/srv/./alice"
      "/srv/alice/"
      "relative"
      "/"
    ];
    expected = true;
  };
  "test external links reject source path values" = {
    expr = invalid (link // { target = ./links.nix; });
    expected = true;
  };
  "test external links reject store context" = {
    expr = invalid (link // { target = "${pkgs.hello}/bin/hello"; });
    expected = true;
  };
  "test external links reject unsupported representations" = {
    expr = invalid (link // { representation = "writable"; });
    expected = true;
  };
  "test direct external links reject ownership claims" = {
    expr = invalid (link // { users = [ "alice" ]; });
    expected = true;
  };
}
