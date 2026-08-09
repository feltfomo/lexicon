{
  description = "lexicon: the furnish, ownerships, and program libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
      imports = [ inputs.treefmt-nix.flakeModule ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # every library stays a function of its dependencies. the consumer supplies
      # lib, krisis, axiom, and the ownership doors, so nothing here pins a
      # nixpkgs on a caller's behalf.
      #
      # the coordinator is the exception, because it's ours rather than the
      # caller's: the two surfaces that need it get it filled in from our own
      # input. args comes last so a suite can still override it with a throw to
      # prove the pure path never forces the builder.
      flake.lib =
        let
          withCoordinator =
            path: args: import path ({ inherit (inputs.furnish-coordinator.lib) mkCoordinator; } // args);
        in
        {
          ownerships = import ./src/ownerships;
          furnish = import ./src/furnish;
          furnishRuntime = withCoordinator ./src/furnish/runtime.nix;
          program = withCoordinator ./src/program.nix;
          report = import ./src/program/report.nix;
          den = import ./src/den.nix;
          # so a consumer wanting the binary as a package or app builds it with
          # the same builder the reconcile unit uses, still without an input.
          inherit (inputs.furnish-coordinator.lib) mkCoordinator;
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
            packages = [
              pkgs.nixfmt
              pkgs.statix
            ];
          };
        };
    };
}
