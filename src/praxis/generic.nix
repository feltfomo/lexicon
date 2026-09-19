{
  pkgs,
  lexiconSource,
  axiomSource,
  krisisSource,
}:
let
  version = import ./version.nix;
  runner = import ./package.nix { inherit pkgs; };
  probe = pkgs.writeText "praxis-project-probe.nix" ''
    let
      projectRoot = builtins.getEnv "PRAXIS_PROJECT_ROOT";
      project = builtins.getFlake "path:''${projectRoot}";
    in
    if project ? praxis then "yes" else "no"
  '';
  evaluator = pkgs.writeText "praxis-project-evaluator.nix" ''
    let
      projectRoot = builtins.getEnv "PRAXIS_PROJECT_ROOT";
      project = builtins.getFlake "path:''${projectRoot}";
      system = builtins.currentSystem;
      pkgs =
        if project.inputs ? nixpkgs then
          project.inputs.nixpkgs.legacyPackages.''${system}
        else
          throw "praxis: flake.nix must declare a nixpkgs input";
      root = /. + builtins.unsafeDiscardStringContext project.outPath;
      # a project may expose the declaration itself or a function of the project context
      declaration =
        if builtins.isFunction project.praxis then
          project.praxis { inherit pkgs root; }
        else
          project.praxis;
      lib = pkgs.lib;
      axiom = import ${axiomSource}/src { inherit lib; };
      krisis = import ${krisisSource}/src { inherit lib axiom; };
      result = import ${lexiconSource}/src/praxis.nix (
        {
          inherit
            lib
            axiom
            krisis
            pkgs
            root
            ;
        }
        // removeAttrs declaration [ "name" ]
        // {
          name = "praxis";
          _prepareOnly = true;
        }
      );
    in
    result
  '';
in
pkgs.writeShellApplication {
  name = "praxis";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.nix
    runner
  ];
  text = ''
    if [[ "''${1-}" == "--version" ]]; then
      printf 'praxis ${version}\n'
      exit 0
    fi

    generic_help() {
      cat <<'HELP'
    Praxis runs the commands a project's flake.nix exposes as its praxis output.

    Usage:
      praxis list
      praxis help COMMAND
      praxis COMMAND [ARGUMENTS...]

    Run Praxis from a project directory or any directory below it.
    HELP
    }

    wants_generic_help() {
      [[ "$#" -eq 0 || ( "''${1-}" == "help" && "$#" -eq 1 ) ]]
    }

    if [[ "''${1-}" == "--help" ]]; then
      generic_help
      exit 0
    fi

    cursor=$PWD
    while [[ "$cursor" != "/" && ! -e "$cursor/flake.nix" ]]; do
      cursor=$(dirname "$cursor")
    done

    if [[ ! -e "$cursor/flake.nix" ]]; then
      if wants_generic_help "$@"; then
        generic_help
        exit 0
      fi
      printf 'praxis: no project found; expected a flake.nix exposing a praxis output in the current directory or a parent\n' >&2
      exit 66
    fi

    error_file=$(mktemp -t praxis-evaluation.XXXXXX)
    manifest_file=$(mktemp -t praxis-manifest.XXXXXX)
    trap 'rm -f "$error_file" "$manifest_file"' EXIT

    status=0
    exposed=$(PRAXIS_PROJECT_ROOT="$cursor" nix eval \
      --extra-experimental-features pipe-operators \
      --no-write-lock-file \
      --impure \
      --raw \
      --file ${probe} \
      2>"$error_file") || status=$?
    if [[ "$status" -ne 0 ]]; then
      printf 'praxis: could not prepare %s\n' "$cursor" >&2
      cat "$error_file" >&2
      exit "$status"
    fi
    if [[ "$exposed" != "yes" ]]; then
      if wants_generic_help "$@"; then
        generic_help
        exit 0
      fi
      printf 'praxis: %s/flake.nix does not expose a praxis output\n' "$cursor" >&2
      exit 66
    fi

    status=0
    prepared=$(PRAXIS_PROJECT_ROOT="$cursor" nix build \
      --extra-experimental-features pipe-operators \
      --no-write-lock-file \
      --no-link \
      --print-out-paths \
      --impure \
      --file ${evaluator} \
      2>"$error_file") || status=$?
    if [[ "$status" -eq 0 ]]; then
      nix store cat "$prepared/manifest.json" > "$manifest_file" 2>>"$error_file" || status=$?
    fi
    if [[ "$status" -ne 0 ]]; then
      printf 'praxis: could not prepare %s\n' "$cursor" >&2
      cat "$error_file" >&2
      exit "$status"
    fi

    rm -f "$error_file"
    status=0
    ${runner}/bin/praxis --manifest "$manifest_file" "$@" || status=$?
    rm -f "$manifest_file"
    trap - EXIT
    exit "$status"
  '';
  meta = {
    description = "Run the commands a project's flake.nix exposes as its praxis output";
    mainProgram = "praxis";
    platforms = pkgs.lib.platforms.linux;
  };
}
