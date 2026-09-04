{
  description = "lexicon: the furnish, ownerships, and program libraries";

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
    # one axiom across the closure, so krisis's schemas and ours are the same
    # values instead of two copies that merely look alike.
    krisis = {
      url = "github:feltfomo/krisis";
      inputs.axiom.follows = "axiom";
    };
    # furnish links files natively through this rust binary, so the coordinator
    # is lexicon's dependency and not a consumer's. a config adds lexicon and
    # gets the linker with it.
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

      # lexicon owns its framework dependencies. callers may override them for
      # fixtures, but ordinary consumers only add lexicon and pass runtime doors.
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
          ownerships = withDependencies ./src/ownerships;
          furnish = withDependencies ./src/furnish;
          furnishRuntime = withRuntimeDependencies ./src/furnish/runtime.nix;
          program = withCoordinator ./src/program.nix;
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

          # a two-host fleet declared right here. skadi binds these doors to den's
          # real roster; the suites only need one that's unambiguous and stable,
          # and a synthetic fleet keeps them from failing whenever a real host
          # joins.
          #
          # lumi is the away host. several suites prove a payload stays unforced
          # by claiming a host that isn't the build ctx, and a claim on a name the
          # roster has never heard of is a hard error rather than an inactive
          # unit, so the away host has to be declared for "inactive" to mean
          # inactive. feltfomo belongs to both so the host/user relation stays
          # satisfiable.
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

          # the shape den.nix's hostPrincipals projects: the host itself, then
          # every user on it.
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

          checks = {
            furnish-pure = gate "furnish-pure-tests" furnishTests;
            program-boundary = gate "program-boundary-tests" programTests;
            # the import-units suite has no gate of its own; the engine suite's ok
            # forces it.
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
