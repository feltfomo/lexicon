{
  lib,
  pkgs,
  krisis,
  axiom,
  lexicon,
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  hostId = "${system}/workstation";
  target = {
    host = {
      name = "workstation";
      inherit system;
    };
    user = {
      name = "alice";
      home = "/srv/alice";
    };
  };
  systemTarget = {
    host = {
      name = "workstation";
      inherit system;
    };
  };
  defaultHomeTarget = {
    inherit (target) host;
    user.name = "alice";
  };

  direct = lexicon.lib.programDirect { inherit target; };
  directSystem = lexicon.lib.programDirect { target = systemTarget; };
  directDefaultHome = lexicon.lib.programDirect { target = defaultHomeTarget; };
  ownerships = lexicon.lib.ownerships { inherit lib krisis axiom; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { inherit system; })
    (ownerships.define.host "server" { inherit system; })
    (ownerships.define.user "alice" { hosts = [ "workstation" ]; })
    (ownerships.define.user "bob" { hosts = [ "workstation" ]; })
  ];
  ownedProgram = lexicon.lib.programOwnerships { inherit roster; };

  moduleArgsFor = hostName: userName: {
    inherit lib pkgs;
    config = {
      networking.hostName = hostName;
      lexicon.furnish.declarations = [ { } ];
    };
    host = {
      name = hostName;
      inherit system;
      id = "${system}/${hostName}";
    };
    user = {
      name = userName;
      home = "/home/${userName}";
    };
  };

  moduleArgs = (moduleArgsFor "ignored-runtime-name" "ignored-runtime-user") // {
    host = throw "programDirect forced the module host argument";
    user = throw "programDirect forced the module user argument";
  };
  homeArgs = {
    inherit lib pkgs;
    host = throw "programDirect forced the home-manager host argument";
    user = throw "programDirect forced the home-manager user argument";
  };
  declarationsOfWith =
    args: declaration:
    let
      result = declaration.nixos args;
      module = builtins.head (
        builtins.filter (candidate: builtins.isAttrs candidate && candidate ? lexicon) result.imports
      );
    in
    module.lexicon.furnish.declarations;
  declarationsOf = declarationsOfWith moduleArgs;

  moduleKey =
    module:
    if builtins.isFunction module then
      (module {
        inherit lib pkgs;
        config = { };
      }).key or null
    else if builtins.isAttrs module then
      module.key or null
    else
      null;
  moduleKeysOf = declaration: map moduleKey (declaration.nixos moduleArgs).imports;
  hasFurnishRuntime =
    declaration: builtins.elem "lexicon/furnish/runtime.nix" (moduleKeysOf declaration);

  packageOnly = direct { pkg = packages: packages.hello; };
  importedModule = {
    home.sessionVariables.EDITOR = "hx";
  };
  importsOnly = direct { imports = [ importedModule ]; };
  normalNixos = {
    users.users.alice.isNormalUser = true;
  };
  nixosOnly = directSystem { nixos = normalNixos; };
  fileOnly = direct {
    files = [
      {
        dest = ".config/direct/example";
        src = ../../src/program.nix;
      }
    ];
  };
  defaultHomeFile = directDefaultHome {
    files = [
      {
        dest = ".config/direct/default-home";
        src = ../../src/program.nix;
      }
    ];
  };
  combined = direct {
    pkg = packages: packages.hello;
    nixos = normalNixos;
    files = [
      {
        dest = ".config/direct/combined";
        src = ../../src/program.nix;
      }
    ];
  };

  directoryOnly = direct {
    directories = [
      {
        src = ./fixtures/sample-tree;
        dest = ".config/direct/tree";
      }
    ];
  };
  themeOnly = direct {
    theme = {
      id = "direct-theme";
      renderers.noctalia = {
        source = ./fixtures/sample-tree/safe-render.nix;
        output = ".config/direct/theme.conf";
      };
    };
  };

  fileDeclarations = declarationsOf fileOnly;
  fileDeclaration = builtins.head fileDeclarations;
  defaultHomeDeclaration = builtins.head (declarationsOf defaultHomeFile);
  directoryDestinations = map (declaration: declaration.destination) (declarationsOf directoryOnly);
  themeDestinations = map (declaration: declaration.destination) (declarationsOf themeOnly);
  packageModule = packageOnly.homeManager homeArgs;
  importsModule = importsOnly.homeManager homeArgs;
  nixosModule = nixosOnly.nixos moduleArgs;

  runtimeOptions =
    { lib, ... }:
    {
      options = {
        networking.hostName = lib.mkOption {
          type = lib.types.str;
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
      config.networking.hostName = "runtime-name";
    };

  fileEvaluation = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      runtimeOptions
      fileOnly.nixos
    ];
  };
  fileManifest = fileEvaluation.config.lexicon.furnish.manifestData;
  manifestEntry = builtins.head fileManifest;

  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  lazyDirect = lexicon.lib.programDirect {
    inherit
      lib
      krisis
      axiom
      ;
    mkCoordinator = throw "package-only direct mode forced the furnish coordinator";
    target = systemTarget;
  };
  lazyPackageResult = builtins.tryEval (
    let
      evaluated = (lazyDirect { pkg = packages: packages.hello; }).homeManager homeArgs;
    in
    evaluated.imports == [ ] && builtins.length evaluated.config.content.home.packages == 1
  );

  topClaimFails = fails (direct {
    users = [ "alice" ];
  });
  fileClaimFails = fails (
    (direct {
      files = [
        {
          users = [ "alice" ];
          dest = ".config/direct/claimed";
          src = ../../src/program.nix;
        }
      ];
    }).nixos
      moduleArgs
  );
  directoryClaimFails = fails (
    (direct {
      directories = [
        {
          hosts = [ "workstation" ];
          src = ./fixtures/sample-tree;
          dest = ".config/direct/claimed-tree";
        }
      ];
    }).nixos
      moduleArgs
  );
  directoryRuleClaimFails = fails (
    (direct {
      directories = [
        {
          src = ./fixtures/sample-tree;
          dest = ".config/direct/claimed-rule";
          files = [
            {
              names = [ "default.nix" ];
              when = _: true;
            }
          ];
        }
      ];
    }).nixos
      moduleArgs
  );
  themeClaimFails = fails (
    (direct {
      theme = {
        id = "claimed-theme";
        renderers.noctalia = {
          users = [ "alice" ];
          source = ./fixtures/sample-tree/safe-render.nix;
          output = ".config/direct/claimed-theme";
        };
      };
    }).nixos
      moduleArgs
  );
  missingUserFails = fails (
    (directSystem {
      files = [
        {
          dest = ".config/direct/no-user";
          src = ../../src/program.nix;
        }
      ];
    }).nixos
      moduleArgs
  );
  invalidTargetFails = fails (lexicon.lib.programDirect { target = { }; });
  missingHostIdentityFails = fails (
    lexicon.lib.programDirect {
      target.host.name = "workstation";
    }
  );

  aliceArgs = moduleArgsFor "workstation" "alice";
  bobArgs = moduleArgsFor "workstation" "bob";
  serverArgs = moduleArgsFor "server" "alice";
  globalImport = {
    home.sessionVariables.GLOBAL = "yes";
  };
  selectedImport = {
    home.sessionVariables.SELECTED = "yes";
  };
  globalOwned = ownedProgram { imports = [ globalImport ]; };
  selectedOwned = ownedProgram {
    hosts = [ "workstation" ];
    users = [ "alice" ];
    imports = [ selectedImport ];
  };
  excludedOwned = ownedProgram {
    exceptUsers = [ "bob" ];
    when = context: context.host.id == hostId;
    imports = [ selectedImport ];
  };
  homeImportsWith = args: declaration: (declaration.homeManager args).imports;

  selectedFile = ownedProgram {
    files = [
      {
        users = [ "alice" ];
        dest = ".config/owned/alice";
        src = ../../src/program.nix;
      }
    ];
  };
  aliceFileDeclarations = declarationsOfWith aliceArgs selectedFile;
  bobFileDeclarations = declarationsOfWith bobArgs selectedFile;

  systemOwned = ownedProgram {
    nixos = [
      {
        hosts = [ "workstation" ];
        services.programBoundary.selected = true;
      }
      {
        hosts = [ "server" ];
        services.programBoundary.server = true;
      }
    ];
  };
  workstationSystem = systemOwned.nixos aliceArgs;
  serverSystem = systemOwned.nixos serverArgs;

  inactiveMalformedOwned = ownedProgram {
    files = [
      {
        users = [ "bob" ];
        dest = throw "forced an inactive ownership destination";
        src = throw "forced an inactive ownership source";
      }
    ];
  };
  inactiveOwnedResult = builtins.tryEval (
    builtins.deepSeq (declarationsOfWith aliceArgs inactiveMalformedOwned) true
  );
  invalidRosterFails = fails (lexicon.lib.programOwnerships { roster = { }; });

  denFixture = {
    hosts.${system}.workstation = {
      dimensions = { };
      users.alice = throw "programDen forced a Den user value";
      aspect = throw "programDen forced Den aspect internals";
      instantiate = throw "programDen forced Den host instantiation";
    };
    lib = throw "programDen forced den.lib";
  };
  denProgram = lexicon.lib.programDen { den = denFixture; };
  denFile = denProgram {
    files = [
      {
        dest = ".config/den/alice";
        src = ../../src/program.nix;
      }
    ];
  };
  denResult = builtins.tryEval (builtins.deepSeq (declarationsOfWith aliceArgs denFile) true);
  denDeclarations = if denResult.success then declarationsOfWith aliceArgs denFile else [ ];
  denBindingSource = builtins.readFile ../../src/program/den.nix;

  sharedSpec = {
    files = [
      {
        dest = ".config/direct/rebound";
        src = ../../src/program.nix;
      }
    ];
  };
  rebound = lexicon.lib.programDirect {
    target = {
      inherit (target) host;
      user = {
        name = "bob";
        home = "/srv/bob";
      };
    };
  } sharedSpec;
  reboundDeclaration = builtins.head (declarationsOf rebound);
  emptyDirect = direct { };
in
{
  public-program-export-remains-a-function = builtins.isFunction lexicon.lib.program;
  public-direct-export-exists = builtins.isFunction lexicon.lib.programDirect;
  public-ownerships-export-exists = builtins.isFunction lexicon.lib.programOwnerships;
  public-den-export-exists = builtins.isFunction lexicon.lib.programDen;

  direct-package-only-is-sparse =
    builtins.attrNames packageOnly == [ "homeManager" ]
    && packageModule.config.content.home.packages == [ pkgs.hello ];
  direct-imports-only-is-sparse =
    builtins.attrNames importsOnly == [ "homeManager" ] && importsModule.imports == [ importedModule ];
  direct-nixos-only-is-sparse-and-ordinary =
    builtins.attrNames nixosOnly == [ "nixos" ]
    && nixosModule.imports == [ normalNixos ]
    && (builtins.head nixosModule.imports).users.users.alice.isNormalUser
    && !hasFurnishRuntime nixosOnly;
  direct-package-only-has-no-furnish-runtime = !(packageOnly ? nixos);
  direct-imports-only-has-no-furnish-runtime = !(importsOnly ? nixos);
  direct-file-only-is-sparse =
    builtins.attrNames fileOnly == [ "nixos" ] && hasFurnishRuntime fileOnly;
  direct-combined-output-is-the-required-union =
    builtins.attrNames combined == [
      "homeManager"
      "nixos"
    ]
    && hasFurnishRuntime combined;
  constructing-direct-program-is-inert = emptyDirect == { };
  package-only-direct-mode-leaves-file-machinery-lazy = lazyPackageResult.success;

  direct-file-lowers-to-one-furnish-declaration =
    builtins.length fileDeclarations == 1
    && fileDeclaration.destination == ".config/direct/example"
    &&
      fileDeclaration.source == {
        kind = "path";
        value = ../../src/program.nix;
      };
  direct-file-defaults-remain-symlink-and-error =
    fileDeclaration.representation == "symlink"
    && !(fileDeclaration ? onConflict)
    && manifestEntry.representation == "symlink"
    && manifestEntry.onConflict == "error";
  direct-target-supplies-authority-root-and-namespace =
    fileDeclaration.authority == {
      scope = "user";
      identity = "alice";
    }
    && fileDeclaration.managedRoot == "/srv/alice"
    && fileDeclaration.filesystemNamespace == hostId
    && manifestEntry.filesystemIdentity.destination == "/srv/alice/.config/direct/example";
  direct-user-home-defaults-from-name = defaultHomeDeclaration.managedRoot == "/home/alice";
  direct-specifications-can-be-rebound-to-another-target =
    reboundDeclaration.authority.identity == "bob"
    && reboundDeclaration.managedRoot == "/srv/bob"
    && reboundDeclaration.filesystemNamespace == hostId;
  direct-directory-expansion-is-preserved =
    builtins.elem ".config/direct/tree/default.nix" directoryDestinations
    && builtins.elem ".config/direct/tree/diagnostics.nix" directoryDestinations
    && hasFurnishRuntime directoryOnly;
  direct-theme-backend-still-lowers-files =
    builtins.elem ".config/noctalia/templates/direct-theme/safe-render.nix" themeDestinations
    && builtins.elem ".config/noctalia/direct-theme.toml" themeDestinations
    && hasFurnishRuntime themeOnly;
  direct-top-level-claims-are-rejected = topClaimFails;
  direct-file-claims-are-rejected = fileClaimFails;
  direct-directory-claims-are-rejected = directoryClaimFails;
  direct-directory-rule-claims-are-rejected = directoryRuleClaimFails;
  direct-theme-claims-are-rejected = themeClaimFails;
  direct-files-require-a-user-target = missingUserFails;
  invalid-direct-targets-are-rejected = invalidTargetFails;
  direct-filesystem-target-needs-host-identity = missingHostIdentityFails;

  ownerships-binding-accepts-a-roster = builtins.isFunction ownedProgram;
  ownerships-global-declarations-apply =
    homeImportsWith aliceArgs globalOwned == [ globalImport ]
    && homeImportsWith bobArgs globalOwned == [ globalImport ];
  ownerships-host-and-user-claims-select-context =
    homeImportsWith aliceArgs selectedOwned == [ selectedImport ]
    && homeImportsWith bobArgs selectedOwned == [ ];
  ownerships-exclusions-and-predicates-select-context =
    homeImportsWith aliceArgs excludedOwned == [ selectedImport ]
    && homeImportsWith bobArgs excludedOwned == [ ];
  ownerships-inactive-malformed-payloads-stay-lazy = inactiveOwnedResult.success;
  ownerships-files-only-reach-the-selected-user =
    builtins.length aliceFileDeclarations == 1
    && builtins.length bobFileDeclarations == 0
    && (builtins.head aliceFileDeclarations).authority.identity == "alice";
  ownerships-system-slices-select-canonical-hosts =
    workstationSystem.services.programBoundary.selected
    && !(workstationSystem.services.programBoundary.server or false)
    && serverSystem.services.programBoundary.server
    && !(serverSystem.services.programBoundary.selected or false);
  invalid-ownerships-rosters-are-rejected = invalidRosterFails;

  den-binding-uses-the-adapter-boundary =
    lib.hasInfix "import ../den.nix" denBindingSource
    && !lib.hasInfix "den.hosts" denBindingSource
    && !lib.hasInfix "den.lib" denBindingSource
    && !lib.hasInfix "den.aspects" denBindingSource;
  den-binding-does-not-force-host-instantiation = denResult.success;
  den-binding-keeps-the-program-output-shape = builtins.attrNames denFile == [ "nixos" ];
  den-binding-resolves-one-user-file-to-one-principal =
    builtins.length denDeclarations == 1
    &&
      (builtins.head denDeclarations).authority == {
        scope = "user";
        identity = "alice";
      }
    && (builtins.head denDeclarations).managedRoot == "/home/alice"
    && (builtins.head denDeclarations).filesystemNamespace == hostId;
}
