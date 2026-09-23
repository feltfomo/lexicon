{
  description = "lexicon: declarative configuration built on nix-effects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # shared with nix-effects so both suites run on one nix-unit
    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-github-actions.follows = "";
      inputs.treefmt-nix.follows = "";
    };

    nix-effects = {
      url = "github:kleisli-io/nix-effects";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-unit.follows = "nix-unit";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake =
        let
          # the only place src/ gets constructed. fixtures override lib or fx here
          lexicon =
            {
              lib ? inputs.nixpkgs.lib,
              fx ? inputs.nix-effects.lib,
            }:
            import ./src { inherit lib fx; };
        in
        {
          lib = {
            inherit lexicon;
            default = lexicon { };
          };
        };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          packages.lexicon = pkgs.callPackage ./cli/package.nix { };

          # nix fmt reaches the same program the gate below runs, so there is
          # one answer to what a formatted tree looks like
          formatter = config.packages.lexicon;

          # the suite is a file with store paths baked in, not a flake output.
          # nix-unit carries its own cpp nix and --flake would re-lock under lix
          checks.tests =
            let
              suite = pkgs.writeText "lexicon-suite.nix" ''
                let
                  lib = import ${inputs.nixpkgs}/lib;
                  fx = import ${inputs.nix-effects} { inherit lib; };
                in
                import ${./tests} {
                  inherit lib fx;
                  lexicon = import ${./src} { inherit lib fx; };
                  mkLexicon = import ${./src};
                }
              '';
            in
            pkgs.runCommand "lexicon-tests"
              {
                nativeBuildInputs = [ inputs.nix-unit.packages.${system}.default ];
              }
              ''
                export HOME="$(realpath .)"
                # nix-unit's bundled evaluator still gates pipe operators and
                # only reads them from the environment
                export NIX_CONFIG="extra-experimental-features = pipe-operators"
                nix-unit --eval-store "$HOME" ${suite}
                touch $out
              '';

          # a formatting regression is caught here rather than by whoever next
          # runs the formatter, which is what the tree had before the
          # multiplexer took the job over
          #
          # the source below is already filtered to what git tracks and the
          # sandbox has no git, so the walk rather than the tracked list answers
          # here and the two sets agree
          checks.formatting =
            pkgs.runCommand "lexicon-formatting"
              {
                nativeBuildInputs = [ config.packages.lexicon ];
              }
              ''
                cd ${./.}
                lexicon fmt --check .
                touch $out
              '';

          # the internal directory name may appear in file paths and import
          # lines, and nowhere a user can read
          checks.source-hygiene = pkgs.runCommand "lexicon-source-hygiene" { } ''
            cd ${./src}
            offenders="$(grep -rn "koseki" . | grep -v 'import \./koseki' || true)"
            if [ -n "$offenders" ]; then
              echo "internal name leaked into readable source:" >&2
              echo "$offenders" >&2
              exit 1
            fi
            touch $out
          '';

          # the formatter is reached with nix fmt rather than carried here,
          # because a shell holding the formatter would have to build the crate
          # before anyone could enter the shell to work on the crate
          devShells.default = pkgs.mkShell {
            packages = [
              inputs.nix-unit.packages.${system}.default
            ]
            ++ (with pkgs; [
              deadnix
              git
              jq
              nixd
              nixfmt
              statix
            ])
            # the formatter is built from cli/, and rustc stays for poc/. the
            # poc cli is not listed here because it takes this flake as an
            # input; run it with
            #   nix run path:$PWD/poc#cli -- --help
            ++ (with pkgs; [
              cargo
              clippy
              rustc
              rustfmt
              odin
              zig
            ]);
          };
        };
    };
}
