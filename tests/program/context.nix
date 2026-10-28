{
  lib,
  pkgs,
  lexicon,
  axiom,
  krisis,
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  ownerships = lexicon.lib.ownerships { inherit lib axiom krisis; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { inherit system; })
    (ownerships.define.host "server" { inherit system; })
    (ownerships.define.user "alice" {
      hosts = [
        "workstation"
        "server"
      ];
    })
    (ownerships.define.user "bob" {
      hosts = [
        "workstation"
        "server"
      ];
    })
  ];
  owned = lexicon.lib.programOwnerships { inherit roster; };
  target = {
    host = {
      name = "workstation";
      inherit system;
    };
    user.name = "alice";
  };
  direct = lexicon.lib.programDirect { inherit target; };
  argsFor = host: user: {
    inherit lib pkgs;
    host = {
      name = host;
      inherit system;
      id = "${system}/${host}";
    };
    user = {
      name = user;
      home = "/home/${user}";
    };
    config = {
      networking.hostName = host;
      lexicon.furnish.declarations = [ { } ];
    };
  };
  alice = argsFor "workstation" "alice";
  bob = argsFor "server" "bob";
  declarations =
    args: aspect:
    let
      result = aspect.nixos args;
    in
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon) result.imports
    )).lexicon.furnish.declarations;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  skillSources = {
    ${system} = ./fixtures/sample-tree;
  };
  skills = import ../../examples/program-skills/skills.nix {
    lexicon = owned;
    sources = skillSources;
  };
  aliceDeclarations = declarations alice skills;
  bobDeclarations = declarations bob skills;
  external = entries: builtins.filter (entry: entry.source.kind == "external") entries;
  native = direct {
    imports = [ { config.result.compatible = true; } ];
    homeManager =
      {
        lib,
        pkgs,
        config,
        host,
        user,
        custom,
        ...
      }:
      {
        options.result = lib.mkOption { type = lib.types.attrs; };
        imports = [ { config.result.imported = true; } ];
        config._module.args.provided = "native";
        config.result = {
          inherit custom;
          host = host.name;
          user = user.name;
          package = pkgs.hello.pname;
          service = "${pkgs.git}/bin/git";
          recursive = config.result.custom;
        };
      };
  };
  home =
    (lib.evalModules {
      specialArgs = {
        inherit pkgs;
        host = throw "forced outer host";
        user = throw "forced outer user";
      };
      modules = [
        native.homeManager
        { _module.args.custom = "argument"; }
        ({ provided, ... }: { config.result.provided = provided; })
      ];
    }).config;
  selectedHome = owned {
    users = [ "alice" ];
    homeManager = { user, ... }: { config.result.user = user.name; };
  };
  selectedHomeConfig =
    (lib.evalModules {
      specialArgs = {
        inherit pkgs;
        inherit (alice) host user;
      };
      modules = [
        selectedHome.homeManager
        { options.result = lib.mkOption { type = lib.types.attrs; }; }
      ];
    }).config;
  inactive = owned {
    users = [ "bob" ];
    files = _: throw "forced inactive files callback";
    links = _: throw "forced inactive links callback";
    directories = _: throw "forced inactive directories callback";
    homeManager = _: throw "forced inactive home callback";
  };
  scoped = owned {
    hosts = [ "workstation" ];
    files =
      {
        user,
        host,
        pkgs,
        ...
      }:
      [
        {
          users = [ "alice" ];
          src = pkgs.hello;
          dest = ".config/${host.name}/${user.name}";
        }
        {
          users = [ "bob" ];
          src = throw "forced nested source";
          dest = throw "forced nested dest";
        }
      ];
  };
  directories = owned {
    directories = _: [
      {
        users = [ "bob" ];
        src = throw "forced unselected directory";
        dest = "inactive";
      }
      {
        users = [
          "alice"
          "bob"
        ];
        src = ./fixtures/sample-tree;
        dest = ".config/tree";
        files = [
          {
            names = [ "diagnostics.nix" ];
            users = [ "bob" ];
          }
        ];
      }
    ];
    theme = {
      id = "dynamic";
      renderers.noctalia = {
        source = ./fixtures/sample-tree/safe-render.nix;
        output = ".config/template";
      };
    };
  };
  destinations = map (entry: entry.destination) (declarations alice directories);
  malformed = name: owned { ${name} = _: { wrong = true; }; };
  claimed = name: value: (direct { ${name} = _: value; }).nixos alice;
  source = ../../src/program.nix;
  empty = owned {
    files = _: [ ];
    links = _: [ ];
    directories = _: [ ];
  };
  directSkills = import ../../examples/program-skills/skills.nix {
    lexicon = direct;
    sources = skillSources;
  };
  skillHome = (directSkills.homeManager alice).imports;
  skillService =
    ((builtins.head skillHome) { inherit lib pkgs; }).systemd.user.services.skills-bootstrap;
in
{
  "test context skills stays direct and sparse" = {
    expr = builtins.attrNames skills;
    expected = [
      "homeManager"
      "nixos"
    ];
  };
  "test context skills two host user targets" = {
    expr =
      builtins.length aliceDeclarations == 12
      && builtins.length bobDeclarations == 12
      && builtins.length (external aliceDeclarations) == 9
      && builtins.length (external bobDeclarations) == 9
      && builtins.all (
        entry: entry.authority.identity == "alice" && entry.filesystemNamespace == "${system}/workstation"
      ) aliceDeclarations
      && builtins.all (
        entry: entry.authority.identity == "bob" && entry.filesystemNamespace == "${system}/server"
      ) bobDeclarations
      && builtins.all (entry: lib.hasPrefix "/home/alice/Projects/skills/" entry.source.value) (
        external aliceDeclarations
      )
      && builtins.all (entry: lib.hasPrefix "/home/bob/Projects/skills/" entry.source.value) (
        external bobDeclarations
      );
    expected = true;
  };
  "test context home manager native module" = {
    expr = home.result;
    expected = {
      compatible = true;
      imported = true;
      custom = "argument";
      recursive = "argument";
      provided = "native";
      host = "workstation";
      user = "alice";
      package = "hello";
      service = "${pkgs.git}/bin/git";
    };
  };
  "test context home manager skills service" = {
    expr =
      skillService.Service.ExecStart
      == "${pkgs.git}/bin/git clone https://github.com/feltfomo/skills /home/alice/Projects/skills"
      && skillService.Service.ExecStartPre == "${pkgs.coreutils}/bin/mkdir -p /home/alice/Projects"
      && skillService.Unit.ConditionPathExists == "!/home/alice/Projects/skills";
    expected = true;
  };
  "test context home manager attr module" = {
    expr =
      (builtins.head
        ((direct { homeManager.home.sessionVariables.EDITOR = "hx"; }).homeManager alice).imports
      ).home.sessionVariables.EDITOR;
    expected = "hx";
  };
  "test context owned home manager only is selected" = {
    expr = selectedHomeConfig.result.user;
    expected = "alice";
  };
  "test context inactive callbacks stay lazy" = {
    expr = declarations alice inactive == [ ] && (inactive.homeManager alice).imports == [ ];
    expected = true;
  };
  "test context outer and nested claims select" = {
    expr =
      builtins.length (declarations alice scoped) == 1
      && declarations bob scoped == [ ]
      && (builtins.head (declarations alice scoped)).destination == ".config/workstation/alice";
    expected = true;
  };
  "test context directory indices rules and theme reservations" = {
    expr =
      builtins.elem ".config/tree/default.nix" destinations
      && !(builtins.elem ".config/tree/diagnostics.nix" destinations)
      && !(builtins.elem ".config/tree/safe-render.nix" destinations)
      && builtins.elem ".config/noctalia/templates/dynamic/safe-render.nix" destinations;
    expected = true;
  };
  "test context empty callbacks are inert" = {
    expr = declarations alice empty;
    expected = [ ];
  };
  "test context malformed results rejected" = {
    expr = builtins.all (name: fails ((malformed name).nixos alice)) [
      "files"
      "links"
      "directories"
    ];
    expected = true;
  };
  "test context direct file claims rejected" = {
    expr = claimed "files" [
      {
        users = [ "alice" ];
        src = source;
        dest = "a";
      }
    ];
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.files\\[0\\]\\.users: direct binding rejects ownership annotations";
  };
  "test context direct link claims rejected" = {
    expr = claimed "links" [
      {
        when = _: true;
        target = "/external";
        dest = "a";
      }
    ];
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.links\\[0\\]\\.when: direct binding rejects ownership annotations";
  };
  "test context direct directory claims rejected" = {
    expr = claimed "directories" [
      {
        hosts = [ "workstation" ];
        src = ./fixtures/sample-tree;
        dest = "a";
      }
    ];
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.directories\\[0\\]\\.hosts: direct binding rejects ownership annotations";
  };
  "test context direct directory rule claims rejected" = {
    expr = claimed "directories" [
      {
        src = ./fixtures/sample-tree;
        dest = "a";
        files = [
          {
            users = [ "alice" ];
            names = [ "default.nix" ];
          }
        ];
      }
    ];
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.directories\\[0\\]\\.files\\[0\\]\\.users: direct binding rejects ownership annotati";
  };
  "test context direct callbacks require user at declaration" = {
    expr = (lexicon.lib.programDirect { target.host = target.host; }) { files = _: [ ]; };
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/resource-user\\] \\$\\.target\\.user: resource-producing declarations require a concrete user target";
  };
}
