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
  packagesOf =
    module:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        module
        {
          options.home.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
        }
      ];
    }).config.home.packages;
  packageModule = packagesOf packageOnly.homeManager;
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
    builtins.length (packagesOf evaluated) == 1
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
  denAdapter = lexicon.lib.den { den = denFixture; };
  denProjection = {
    inherit system;
    host = "workstation";
  };
  denHostPrincipals = denAdapter.hostPrincipals denProjection;
  denSelectedPrincipals = denAdapter.filePrincipals (
    denProjection
    // {
      user = {
        name = "alice";
        unused = throw "filePrincipals forced an unrelated resolved-user field";
      };
    }
  );
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
  denBindingSource = builtins.readFile ../../src/lexicon/default.nix;

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

  bridgeOptions = {
    options =
      lib.genAttrs
        [
          "bridgeMarker"
          "bridgeChoice"
          "bridgeIdentity"
          "bridgeObservedConfig"
          "bridgeNestedArgument"
        ]
        (
          _:
          lib.mkOption {
            type = lib.types.str;
            default = "";
          }
        )
      // {
        bridgeOrder = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };
    config.bridgeMarker = "home-manager-config";
  };
  outerBridgeImport = { lib, ... }: {
    bridgeChoice = lib.mkDefault "import-default";
    bridgeOrder = lib.mkBefore [ "outer" ];
  };
  innerBridgeImport = { lib, bridgeArgument, ... }: {
    bridgeNestedArgument = bridgeArgument;
    bridgeOrder = lib.mkBefore [ "inner" ];
  };
  bridgeBody =
    imports:
    {
      lib,
      config,
      host,
      user,
      bridgeArgument,
      ...
    }:
    {
      inherit imports;
      bridgeChoice = lib.mkForce "body-force";
      bridgeOrder = [ "body" ];
      bridgeIdentity = "${host.name}/${user.name}/${bridgeArgument}";
      bridgeObservedConfig = config.bridgeMarker;
    };
  legacyBridges = direct {
    imports = [ outerBridgeImport ];
    homeManager = bridgeBody [ innerBridgeImport ];
    files = { config, ... }: [
      {
        dest = ".config/${config.bridgeMarker}";
        src = ../../src/program.nix;
      }
    ];
  };
  canonicalBridges = (lexicon.lib.lexicon.forTarget { inherit target; }) {
    homeManager = bridgeBody [
      outerBridgeImport
      innerBridgeImport
    ];
    furnish.files = { config, ... }: [
      {
        destination = ".config/${config.bridgeMarker}";
        source = ../../src/program.nix;
      }
    ];
  };
  evaluateBridge =
    module:
    (lib.evalModules {
      specialArgs = {
        inherit pkgs;
        bridgeArgument = "requested-native-argument";
        host = throw "native bridge forced the runtime host";
        user = throw "native bridge forced the runtime user";
      };
      modules = [
        bridgeOptions
        module
      ];
    }).config;
  legacyBridgeConfig = evaluateBridge legacyBridges.homeManager;
  canonicalBridgeConfig = evaluateBridge canonicalBridges.homeManager;
  bridgeProjection = config: {
    inherit (config)
      bridgeChoice
      bridgeOrder
      bridgeIdentity
      bridgeObservedConfig
      bridgeNestedArgument
      ;
  };
  resourceBridgeArgs = moduleArgs // {
    config = moduleArgs.config // {
      bridgeMarker = "nixos-resource-config";
    };
  };
  recoveringProvider = {
    mkDiagnosticFactory =
      defaults: raw:
      (krisis.mkDiagnosticFactory defaults raw) // { message = "injected target diagnostic"; };
    mkReporter =
      options:
      let
        original = krisis.mkReporter options;
      in
      original
      // {
        finish =
          result:
          if result.diagnostics == [ ] then
            original.finish result
          else
            {
              host = {
                name = "recovered";
                inherit system;
                marker = (builtins.head result.diagnostics).message;
              };
              user = null;
            };
      };
  };
  recoveredDirect = lexicon.lib.programDirect {
    krisis = recoveringProvider;
    mkCoordinator = throw "native target recovery forced file machinery";
    target.host = {
      name = 1;
      inherit system;
    };
  };
  recoveredConfig =
    evaluateBridge
      (recoveredDirect {
        homeManager = { host, ... }: { bridgeIdentity = host.marker; };
      }).homeManager;
in
{
  "test native bridge preserves imports priorities and requested arguments" = {
    expr = bridgeProjection legacyBridgeConfig;
    expected = {
      bridgeChoice = "body-force";
      bridgeOrder = [
        "inner"
        "outer"
        "body"
      ];
      bridgeIdentity = "workstation/alice/requested-native-argument";
      bridgeObservedConfig = "home-manager-config";
      bridgeNestedArgument = "requested-native-argument";
    };
  };
  "test canonical and legacy native bridges evaluate equally" = {
    expr = bridgeProjection canonicalBridgeConfig;
    expected = bridgeProjection legacyBridgeConfig;
  };
  "test native and resource bridges keep separate configurations" = {
    expr =
      legacyBridgeConfig.bridgeObservedConfig == "home-manager-config"
      && canonicalBridgeConfig.bridgeObservedConfig == "home-manager-config"
      &&
        (builtins.head (declarationsOfWith resourceBridgeArgs legacyBridges)).destination
        == ".config/nixos-resource-config"
      &&
        (builtins.head (declarationsOfWith resourceBridgeArgs canonicalBridges)).destination
        == ".config/nixos-resource-config";
    expected = true;
  };
  "test public target normalization honors injected diagnostics and terminal recovery" = {
    expr = recoveredConfig.bridgeIdentity;
    expected = "injected target diagnostic";
  };
  "test public program export remains a function" = {
    expr = builtins.isFunction lexicon.lib.program;
    expected = true;
  };
  "test public direct export exists" = {
    expr = builtins.isFunction lexicon.lib.programDirect;
    expected = true;
  };
  "test public ownerships export exists" = {
    expr = builtins.isFunction lexicon.lib.programOwnerships;
    expected = true;
  };
  "test public den export exists" = {
    expr = builtins.isFunction lexicon.lib.programDen;
    expected = true;
  };

  "test direct package only is sparse" = {
    expr = builtins.attrNames packageOnly == [ "homeManager" ] && packageModule == [ pkgs.hello ];
    expected = true;
  };
  "test direct imports only is sparse" = {
    expr =
      builtins.attrNames importsOnly == [ "homeManager" ] && importsModule.imports == [ importedModule ];
    expected = true;
  };
  "test direct nixos only is sparse and ordinary" = {
    expr =
      builtins.attrNames nixosOnly == [ "nixos" ]
      && nixosModule.imports == [ normalNixos ]
      && (builtins.head nixosModule.imports).users.users.alice.isNormalUser
      && !hasFurnishRuntime nixosOnly;
    expected = true;
  };
  "test direct package only has no furnish runtime" = {
    expr = !(packageOnly ? nixos);
    expected = true;
  };
  "test direct imports only has no furnish runtime" = {
    expr = !(importsOnly ? nixos);
    expected = true;
  };
  "test direct file only is sparse" = {
    expr = builtins.attrNames fileOnly == [ "nixos" ] && hasFurnishRuntime fileOnly;
    expected = true;
  };
  "test direct combined output is the required union" = {
    expr =
      builtins.attrNames combined == [
        "homeManager"
        "nixos"
      ]
      && hasFurnishRuntime combined;
    expected = true;
  };
  "test constructing direct program is inert" = {
    expr = emptyDirect;
    expected = { };
  };
  "test package only direct mode leaves file machinery lazy" = {
    expr = lazyPackageResult.success;
    expected = true;
  };

  "test direct file lowers to one furnish declaration" = {
    expr =
      builtins.length fileDeclarations == 1
      && fileDeclaration.destination == ".config/direct/example"
      &&
        fileDeclaration.source == {
          kind = "path";
          value = ../../src/program.nix;
        };
    expected = true;
  };
  "test direct file defaults remain symlink and error" = {
    expr =
      fileDeclaration.representation == "symlink"
      && !(fileDeclaration ? onConflict)
      && manifestEntry.representation == "symlink"
      && manifestEntry.onConflict == "error";
    expected = true;
  };
  "test direct target supplies authority root and namespace" = {
    expr =
      fileDeclaration.authority == {
        scope = "user";
        identity = "alice";
      }
      && fileDeclaration.managedRoot == "/srv/alice"
      && fileDeclaration.filesystemNamespace == hostId
      && manifestEntry.filesystemIdentity.destination == "/srv/alice/.config/direct/example";
    expected = true;
  };
  "test direct user home defaults from name" = {
    expr = defaultHomeDeclaration.managedRoot;
    expected = "/home/alice";
  };
  "test direct specifications can be rebound to another target" = {
    expr =
      reboundDeclaration.authority.identity == "bob"
      && reboundDeclaration.managedRoot == "/srv/bob"
      && reboundDeclaration.filesystemNamespace == hostId;
    expected = true;
  };
  "test direct directory expansion is preserved" = {
    expr =
      builtins.elem ".config/direct/tree/default.nix" directoryDestinations
      && builtins.elem ".config/direct/tree/diagnostics.nix" directoryDestinations
      && hasFurnishRuntime directoryOnly;
    expected = true;
  };
  "test direct theme backend still lowers files" = {
    expr =
      builtins.elem ".config/noctalia/templates/direct-theme/safe-render.nix" themeDestinations
      && builtins.elem ".config/noctalia/direct-theme.toml" themeDestinations
      && hasFurnishRuntime themeOnly;
    expected = true;
  };
  "test direct top level claims are rejected" = {
    expr = topClaimFails;
    expected = true;
  };
  "test direct file claims are rejected" = {
    expr = fileClaimFails;
    expected = true;
  };
  "test direct directory claims are rejected" = {
    expr = directoryClaimFails;
    expected = true;
  };
  "test direct directory rule claims are rejected" = {
    expr = directoryRuleClaimFails;
    expected = true;
  };
  "test direct theme claims are rejected" = {
    expr = themeClaimFails;
    expected = true;
  };
  "test direct files require a user target" = {
    expr = missingUserFails;
    expected = true;
  };
  "test invalid direct targets are rejected" = {
    expr = invalidTargetFails;
    expected = true;
  };
  "test direct filesystem target needs host identity" = {
    expr = missingHostIdentityFails;
    expected = true;
  };

  "test ownerships binding accepts a roster" = {
    expr = builtins.isFunction ownedProgram;
    expected = true;
  };
  "test ownerships global declarations apply" = {
    expr =
      homeImportsWith aliceArgs globalOwned == [ globalImport ]
      && homeImportsWith bobArgs globalOwned == [ globalImport ];
    expected = true;
  };
  "test ownerships host and user claims select context" = {
    expr =
      homeImportsWith aliceArgs selectedOwned == [ selectedImport ]
      && homeImportsWith bobArgs selectedOwned == [ ];
    expected = true;
  };
  "test ownerships exclusions and predicates select context" = {
    expr =
      homeImportsWith aliceArgs excludedOwned == [ selectedImport ]
      && homeImportsWith bobArgs excludedOwned == [ ];
    expected = true;
  };
  "test ownerships inactive malformed payloads stay lazy" = {
    expr = inactiveOwnedResult.success;
    expected = true;
  };
  "test ownerships files only reach the selected user" = {
    expr =
      builtins.length aliceFileDeclarations == 1
      && builtins.length bobFileDeclarations == 0
      && (builtins.head aliceFileDeclarations).authority.identity == "alice";
    expected = true;
  };
  "test ownerships system slices select canonical hosts" = {
    expr =
      workstationSystem.services.programBoundary.selected
      && !(workstationSystem.services.programBoundary.server or false)
      && serverSystem.services.programBoundary.server
      && !(serverSystem.services.programBoundary.selected or false);
    expected = true;
  };
  "test invalid ownerships rosters are rejected" = {
    expr = invalidRosterFails;
    expected = true;
  };

  "test den binding uses the adapter boundary" = {
    expr =
      lib.hasInfix "import ../den.nix" denBindingSource
      && !lib.hasInfix "den.hosts" denBindingSource
      && !lib.hasInfix "den.lib" denBindingSource
      && !lib.hasInfix "den.aspects" denBindingSource;
    expected = true;
  };
  "test den binding does not force host instantiation" = {
    expr = denResult.success;
    expected = true;
  };
  "test den roster enumerates without user bodies" = {
    expr =
      denAdapter.roster.hosts == [ hostId ]
      && denAdapter.roster.users == [ "alice" ]
      && denAdapter.roster.membership.${hostId} == [ "alice" ];
    expected = true;
  };
  "test den host user names enumerate without user bodies" = {
    expr = denAdapter.hostUserNames denProjection;
    expected = [ "alice" ];
  };
  "test den host principals enumerate possible authorities" = {
    expr = map (principal: principal.authority) denHostPrincipals;
    expected = [
      {
        scope = "system";
        identity = hostId;
      }
      {
        scope = "user";
        identity = "alice";
      }
    ];
  };
  "test den file principals select one resolved user" = {
    expr =
      builtins.length denSelectedPrincipals == 1
      &&
        (builtins.head denSelectedPrincipals).authority == {
          scope = "user";
          identity = "alice";
        }
      && denAdapter.filePrincipals denProjection == [ ];
    expected = true;
  };
  "test den binding keeps the program output shape" = {
    expr = builtins.attrNames denFile;
    expected = [ "nixos" ];
  };
  "test den binding resolves one user file to one principal" = {
    expr =
      builtins.length denDeclarations == 1
      &&
        (builtins.head denDeclarations).authority == {
          scope = "user";
          identity = "alice";
        }
      && (builtins.head denDeclarations).managedRoot == "/home/alice"
      && (builtins.head denDeclarations).filesystemNamespace == hostId;
    expected = true;
  };
}
