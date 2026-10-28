# evaluates every observation cell in its own evaluator process, keeps what it
# printed, then judges the captures with law.nix. one process per cell keeps one
# cell's traces and failure out of another's. the flake is read from a private
# store with every input handed over by store path, as the unit check does
{
  pkgs,
  lib,
  self,
  nixpkgs,
  inputOverrides,
}:
let
  families = [
    "ownerships"
    "terminals"
    "resources"
    "compiler"
    "effects"
    "praxis"
  ];
  specs = lib.genAttrs families (family: ./. + "/${family}.nix");
  cellNames = family: lib.concatStringsSep " " (builtins.attrNames (import specs.${family}).cells);
in
pkgs.runCommand "lexicon-observation-events"
  {
    nativeBuildInputs = [ pkgs.nix ];
  }
  ''
    set -euo pipefail
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_DATA_HOME="$TMPDIR/share"
    unset NIX_STORE
    export NIX_STORE_DIR=${builtins.storeDir}
    export NIX_REMOTE="$(realpath .)/store"
    features=(--extra-experimental-features "nix-command flakes pipe-operators")
    ${lib.concatMapStrings (family: ''
      mkdir -p "$TMPDIR/events/${family}"
      for cell in ${cellNames family}; do
        status=0
        nix "''${features[@]}" eval --json --show-trace ${lib.concatStringsSep " " inputOverrides} \
          "path:${self}#observations.${family}.$cell" \
          > "$TMPDIR/events/${family}/$cell.stdout" 2> "$TMPDIR/events/${family}/$cell.stderr" || status=$?
        echo "$status" > "$TMPDIR/events/${family}/$cell.exit"
      done
    '') families}
    nix "''${features[@]}" eval --json --impure --expr "
      import ${./law.nix} {
        lib = import ${nixpkgs}/lib;
        families = { ${
          lib.concatMapStrings (family: "${family} = import ${specs.${family}}; ") families
        }};
        dir = \"$TMPDIR/events\";
      }" > "$out"
    cat "$out"
  ''
