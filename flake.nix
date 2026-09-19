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
    # keep schema and validation behavior on one dependency version
    krisis = {
      url = "github:feltfomo/krisis";
      inputs.axiom.follows = "axiom";
    };
    # lexicon owns the coordinator version used by its manifests
    furnish-coordinator = {
      url = "github:feltfomo/furnish-coordinator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
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
          dependenciesFor =
            args:
            let
              lib = args.lib or inputs.nixpkgs.lib;
              axiom = args.axiom or inputs.axiom.lib.axiom { inherit lib; };
              krisis = args.krisis or inputs.krisis.lib.krisis { inherit lib axiom; };
            in
            {
              inherit lib axiom krisis;
            };
          withDependencies = path: args: import path (dependenciesFor args // args);
          withCoordinator =
            path: args:
            withDependencies path ({ inherit (inputs.furnish-coordinator.lib) mkCoordinator; } // args);
          withRuntimeDependencies =
            path: args:
            import path (
              removeAttrs
                (dependenciesFor args // { inherit (inputs.furnish-coordinator.lib) mkCoordinator; } // args)
                [
                  "lib"
                ]
            );
        in
        {
          registry = withDependencies ./src/registry.nix;
          ownerships = withDependencies ./src/ownerships;
          furnish = withDependencies ./src/furnish;
          furnishRuntime = withRuntimeDependencies ./src/furnish/runtime.nix;
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

      flake.nixosConfigurations =
        let
          system = "x86_64-linux";
          pkgs = import inputs.nixpkgs { inherit system; };
          inherit (pkgs) lib;
          axiom = inputs.axiom.lib.axiom { inherit lib; };
          krisis = inputs.krisis.lib.krisis { inherit lib axiom; };

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
          axiom = inputs.axiom.lib.axiom { inherit lib; };
          krisis = inputs.krisis.lib.krisis { inherit lib axiom; };
          ownerships = import ./src/ownerships { inherit lib krisis axiom; };
          praxis = inputs.self.lib.praxis;
          praxisTests = import ./tests/praxis { inherit lib krisis axiom; };
          praxisCompiler = args: import ./src/praxis/compile.nix ({ inherit lib axiom krisis; } // args);
          genericPraxis = import ./src/praxis/generic.nix {
            inherit pkgs;
            lexiconSource = inputs.self;
            axiomSource = inputs.axiom;
            krisisSource = inputs.krisis;
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
            };
            tasks.gate = {
              description = "Format and run the complete Lexicon flake check";
              lock = "lexicon-gate";
              steps = [
                "fmt"
                "check"
              ];
            };
          };

          # a declared away host distinguishes inactive payloads from unknown claims
          roster = ownerships.toRoster [
            (ownerships.define.host "khion" { system = "x86_64-linux"; })
            (ownerships.define.host "lumi" { system = "x86_64-linux"; })
            (ownerships.define.user "feltfomo" {
              hosts = [
                "khion"
                "lumi"
              ];
            })
          ];
          resolve = ownerships.mkResolve roster;
          resolveSystem = ownerships.mkResolveSystem roster;

          hostCtx = {
            id = "x86_64-linux/khion";
            name = "khion";
            system = "x86_64-linux";
          };
          principalContexts = [
            {
              authority = {
                scope = "system";
                identity = "x86_64-linux/khion";
              };
              ctx.host = hostCtx;
            }
            {
              authority = {
                scope = "user";
                identity = "feltfomo";
              };
              ctx = {
                host = hostCtx;
                user.name = "feltfomo";
              };
            }
          ];

          registryTests = import ./tests/registry {
            inherit lib krisis axiom;
          };
          furnishTests = import ./tests/furnish {
            inherit
              lib
              krisis
              axiom
              resolve
              resolveSystem
              principalContexts
              ;
          };
          programTests = import ./tests/program {
            inherit
              lib
              pkgs
              krisis
              axiom
              ;
            lexicon = inputs.self;
          };
          ownershipsTest =
            path:
            import path {
              inherit
                lib
                krisis
                axiom
                ;
            };

          gate =
            name: suite:
            pkgs.runCommandLocal name { } (
              assert suite.ok;
              "touch $out"
            );
        in
        {
          treefmt = import ./formatter.nix;
          packages = {
            praxis = genericPraxis;
            lexicon-praxis = praxisCommands.package;
          };
          apps.lexicon-praxis = praxisCommands.apps.lexicon-praxis;

          checks = {
            registry = gate "registry-tests" registryTests;
            documentation = import ./tests/documentation.nix {
              inherit pkgs;
              inherit (inputs) nixpkgs;
              lexicon = inputs.self;
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
            praxis-pure = gate "praxis-pure-tests" praxisTests;
            praxis-public-surface = gate "praxis-public-surface" (
              import ./tests/praxis/public-surface.nix { inherit lib axiom krisis; }
            );
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
            furnish-pure = gate "furnish-pure-tests" furnishTests;
            program-boundary = gate "program-boundary-tests" programTests;
            # the engine suite includes import-unit boundary tests
            ownerships-engine = gate "ownerships-engine-tests" (ownershipsTest ./tests/ownerships/engine.nix);
            ownerships-roster = gate "ownerships-roster-tests" (ownershipsTest ./tests/ownerships/roster.nix);
            ownerships-surface = gate "ownerships-surface-tests" (
              ownershipsTest ./tests/ownerships/surface.nix
            );
            ownerships-descriptors = gate "ownerships-descriptor-tests" (
              ownershipsTest ./tests/ownerships/descriptors.nix
            );
            ownerships-matrix = gate "ownerships-matrix-tests" (ownershipsTest ./tests/ownerships/matrix.nix);
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              bashInteractive
              praxisCommands.cli
              cargo
              rustc
              rustfmt
              clippy
              deadnix
              delve
              git
              go
              gofumpt
              golangci-lint
              gopls
              jq
              marksman
              nixd
              nixfmt
              shellcheck
              shfmt
              statix
              taplo
            ];
          };
        };
    };
}
