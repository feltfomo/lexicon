{
  description = "lexicon: declarative configuration and project commands with ownerships, furnish, program, and praxis";

  nixConfig.extra-experimental-features = [ "pipe-operators" ];

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    axiom.url = "github:feltfomo/axiom-nix";
    krisis.url = "github:feltfomo/krisis/c48e40834fe90299096d2988433b17f650c30c8a";
    # lexicon owns the coordinator version used by its manifests
    furnish-coordinator = {
      url = "github:feltfomo/furnish-coordinator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      dependenciesFor =
        args:
        let
          lib = args.lib or inputs.nixpkgs.lib;
          axiom = args.axiom or (inputs.axiom.lib.axiom { inherit lib; });
        in
        import ./src/dependencies.nix {
          inherit lib axiom;
          krisisSource = inputs.krisis;
          krisis = args.krisis or null;
        };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        ./tests/system/nix/furnish-coordinator.nix
        ./tests/system/nix/program-files-regression.nix
        ./tests/system/nix/rebuild-vm-golden.nix
        ./tests/system/nix/furnish-coordinator-gate.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # explicit dependency overrides keep isolated fixtures possible
      flake.lib =
        let
          withDependencies = path: args: import path (args // dependenciesFor args);
          withCoordinator =
            path: args:
            withDependencies path ({ inherit (inputs.furnish-coordinator.lib) mkCoordinator; } // args);
          withRuntimeDependencies =
            path: args:
            import path (
              removeAttrs
                ({ inherit (inputs.furnish-coordinator.lib) mkCoordinator; } // args // dependenciesFor args)
                [
                  "lib"
                ]
            );
        in
        {
          toml = args: withDependencies ./src/toml ({ lib = args.pkgs.lib; } // args);
          registry = withDependencies ./src/registry.nix;
          ownerships = withDependencies ./src/ownerships;
          furnish = withDependencies ./src/furnish;
          furnishRuntime = withRuntimeDependencies ./src/furnish/runtime.nix;
          lexicon =
            let
              make = args: withCoordinator ./src/lexicon args;
              factories = [
                "forDen"
                "forRoster"
                "forTarget"
                "withResolvers"
              ];
              configure =
                {
                  extensions ? [ ],
                }:
                let
                  environment = (make { }).configure { inherit extensions; };
                in
                (lib.genAttrs factories (
                  name: args:
                  let
                    deps = builtins.intersectAttrs (lib.genAttrs [ "lib" "axiom" "krisis" "mkCoordinator" ] (
                      _: null
                    )) args;
                  in
                  (
                    if builtins.attrNames deps == [ ] then
                      environment
                    else
                      (make deps).configure { inherit extensions; }
                  ).${name}
                    (removeAttrs args (builtins.attrNames deps))
                ))
                // {
                  inherit (environment) ownerships;
                };
              lib = inputs.nixpkgs.lib;
            in
            { inherit configure; } // configure { };
          program = withCoordinator ./src/program.nix;
          programDirect = withCoordinator ./src/program/direct.nix;
          programOwnerships = withCoordinator ./src/program/ownerships.nix;
          programDen = withCoordinator ./src/program/den.nix;
          praxis = withDependencies ./src/praxis.nix;
          praxisAdapters =
            {
              lib ? inputs.nixpkgs.lib,
            }:
            import ./src/praxis/adapters.nix { inherit lib; };
          report = withDependencies ./src/program/report.nix;
          den = withDependencies ./src/den.nix;
          inherit (inputs.furnish-coordinator.lib) mkCoordinator;
        };

      # pure cases only evaluate derivations, so one fixed system keeps a single tree with stable ids
      flake.tests =
        let
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          inherit (pkgs) lib;
          inherit (dependenciesFor { inherit lib; }) axiom krisis;
        in
        import ./tests {
          inherit
            lib
            pkgs
            axiom
            krisis
            ;
          krisisSource = inputs.krisis;
          lexicon = inputs.self;
          inherit (inputs) nixpkgs;
        };

      # the observation fixtures, one cell per attribute, for the events check to
      # evaluate one process at a time
      flake.observations =
        let
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          inherit (pkgs) lib;
          inherit (dependenciesFor { inherit lib; }) axiom krisis;
        in
        import ./tests/events/fixtures.nix {
          inherit
            lib
            pkgs
            axiom
            krisis
            ;
          krisisSource = inputs.krisis;
          lexicon = inputs.self;
        };

      flake.nixosConfigurations =
        let
          system = "x86_64-linux";
          pkgs = import inputs.nixpkgs { inherit system; };
          inherit (pkgs) lib;
          inherit (dependenciesFor { inherit lib; }) axiom krisis;

          merge =
            left: right:
            lib.zipAttrsWith
              (
                _: values:
                if builtins.all builtins.isList values then
                  builtins.concatLists values
                else if builtins.all builtins.isAttrs values then
                  lib.foldl' merge { } values
                else
                  lib.last values
              )
              [
                left
                right
              ];
          collect =
            ctx: unit:
            let
              hostName = ctx.host.name or null;
              userName = ctx.user.name or null;
              active =
                (!(unit ? when) || unit.when ctx)
                && (!(unit ? hosts) || builtins.elem hostName unit.hosts)
                && (!(unit ? users) || builtins.elem userName unit.users)
                && (!(unit ? exceptHosts) || !(builtins.elem hostName unit.exceptHosts))
                && (!(unit ? exceptUsers) || !(builtins.elem userName unit.exceptUsers));
              own = removeAttrs unit [
                "hosts"
                "users"
                "exceptHosts"
                "exceptUsers"
                "when"
                "children"
              ];
            in
            if !active then { } else lib.foldl' merge own (map (collect ctx) (unit.children or [ ]));
          resolve = units: ctx: lib.foldl' merge { } (map (collect ctx) units);
          program = import ./src/program.nix {
            inherit
              lib
              krisis
              axiom
              resolve
              ;
            resolveSystem = resolve;
            resolvePrepared = resolve;
            inherit (inputs.furnish-coordinator.lib) mkCoordinator;
            filePrincipals = args: [
              {
                authority = {
                  scope = "user";
                  identity = args.user.name;
                };
              }
            ];
            hostUserNames = _: [ "tester" ];
          };
          furnishRuntime = import ./src/furnish/runtime.nix {
            inherit krisis axiom;
            inherit (inputs.furnish-coordinator.lib) mkCoordinator;
          };
          fixtureProgram = program {
            files = [
              {
                dest = ".config/lexicon/static.conf";
                src = ./tests/system/fixture/payload.conf;
              }
              {
                dest = ".config/lexicon/writable.conf";
                src = ./tests/system/fixture/writable.conf;
                representation = "writable";
                onConflict = "runtime-wins";
              }
            ];
          };
        in
        {
          furnish-vm = inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
              host = {
                name = "furnish-vm";
                inherit system;
              };
              user.name = "tester";
            };
            modules = [
              inputs.disko.nixosModules.disko
              furnishRuntime
              fixtureProgram.nixos
              ./tests/system/fixture/host.nix
              ./tests/system/fixture/disko.nix
            ];
          };
          furnish-installer = inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              (import ./tests/system/fixture/installer.nix { inherit inputs; })
            ];
          };
        };

      perSystem =
        { pkgs, ... }:
        let
          inherit (pkgs) lib;
          inherit (dependenciesFor { inherit lib; }) axiom krisis;
          praxis = inputs.self.lib.praxis;
          praxisCompiler = args: import ./src/praxis/compile.nix ({ inherit lib axiom krisis; } // args);
          genericPraxis = import ./src/praxis/generic.nix {
            inherit pkgs;
            lexiconSource = inputs.self;
            axiomSource = inputs.axiom;
            krisisSource = inputs.krisis;
          };
          # measurements pin one evaluator series from the flake's own nixpkgs, so
          # a lock bump moves it in reviewed changes and every record names it
          benchEvaluator = pkgs.nixVersions.nix_2_34;
          benchRunner = import ./bench/runner {
            inherit pkgs;
            evaluator = benchEvaluator;
          };
          praxisCommands = praxis {
            inherit pkgs;
            name = "lexicon-praxis";
            atRoot = true;
            commands = {
              fmt = {
                command = [
                  "nix"
                  "run"
                  "path:.#formatter.${pkgs.stdenv.hostPlatform.system}"
                  "--"
                ];
                description = "Format Lexicon";
              };
              check = {
                command = [
                  "nix"
                  "flake"
                  "check"
                  "path:."
                  "-L"
                ];
                description = "Check Lexicon";
              };
              # nix-unit embeds cppnix, which rejects the lix pipe-operator feature name in nix.conf
              # and applies the flake nixConfig only after it was trusted interactively
              test = {
                command = [
                  "nix-unit"
                  "--option"
                  "extra-experimental-features"
                  "nix-command flakes pipe-operators"
                  "--flake"
                  "path:.#tests"
                ];
                packages = [ pkgs.nix-unit ];
                description = "Run the Lexicon nix-unit suite";
              };
              # later arguments override these, so a run can name another baseline
              # or narrow the workloads
              bench = {
                command = [
                  "nix"
                  "run"
                  "path:.#bench"
                  "--"
                  "compare"
                  "--baseline"
                  "main"
                  "--candidate"
                  "worktree"
                ];
                description = "Compare the working tree with main on the evaluation benchmark workloads";
              };
            };
            tasks.gate = {
              description = "Format, run the complete Lexicon flake check and the nix-unit suite";
              lock = "lexicon-gate";
              steps = [
                "fmt"
                "check"
                "test"
              ];
            };
          };

          # the sandbox has no network, so every locked input is handed to nix-unit by store path
          inputOverrides =
            let
              collect =
                prefix: flakeInputs:
                lib.concatLists (
                  lib.mapAttrsToList (
                    name: input:
                    let
                      path = prefix ++ [ name ];
                    in
                    [ "--override-input ${lib.concatStringsSep "/" path} ${input.outPath}" ]
                    ++ collect path (input.inputs or { })
                  ) (removeAttrs flakeInputs [ "self" ])
                );
            in
            collect [ ] inputs;
        in
        {
          treefmt = import ./formatter.nix;
          packages = {
            praxis = genericPraxis;
            lexicon-praxis = praxisCommands.package;
            bench-evaluator = benchEvaluator;
            bench = benchRunner;
          };
          apps.lexicon-praxis = praxisCommands.apps.lexicon-praxis;

          checks = {
            # the same tree lexicon:test runs, inside a private store so nothing touches the daemon
            unit =
              pkgs.runCommand "lexicon-unit-tests"
                {
                  nativeBuildInputs = [ pkgs.nix-unit ];
                }
                ''
                  export HOME="$(realpath .)"
                  unset NIX_STORE
                  export NIX_STORE_DIR=${builtins.storeDir}
                  export NIX_REMOTE="$HOME/store"
                  nix-unit \
                    --extra-experimental-features "flakes nix-command pipe-operators" \
                    --accept-flake-config \
                    ${lib.concatStringsSep " " inputOverrides} \
                    --flake path:${inputs.self}#tests
                  touch "$out"
                '';
            toml-composition = import ./tests/toml {
              inherit pkgs;
              lexicon = inputs.self;
              inherit (inputs) nixpkgs;
            };
            consumers =
              let
                existing = import ./tests/consumers.nix {
                  inherit pkgs;
                  inherit (inputs) nixpkgs;
                  lexicon = inputs.self;
                };
                installed = import ./tests/praxis/installed.nix {
                  inherit pkgs genericPraxis;
                };
              in
              pkgs.linkFarm "lexicon-consumer-checks" [
                {
                  name = "existing";
                  path = existing;
                }
                {
                  name = "installed-praxis";
                  path = installed;
                }
              ];
            praxis-generated-cli = import ./tests/praxis/generated-cli.nix { inherit pkgs praxis; };
            praxis-integration = import ./tests/praxis/integration.nix {
              inherit pkgs;
              praxis = praxisCompiler;
            };
            praxis-runtime = import ./tests/praxis/runtime.nix {
              inherit pkgs;
              praxis = praxisCompiler;
            };
            praxis-runner = praxisCommands.runner;
            # building the runner is what shellchecks its script
            bench-runner = benchRunner;
            bench-reduce = import ./tests/bench/reduce.nix {
              inherit pkgs;
              runner = benchRunner;
            };
            # callback counts, call order and error contexts of the observation fixtures
            observation-events = import ./tests/events/check.nix {
              inherit pkgs lib inputOverrides;
              inherit (inputs) self nixpkgs;
            };
          };
        };
    };
}
