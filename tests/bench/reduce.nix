# the runner's profile reduction over folded stacks written here. a recursing
# marker counts once per stack, a frame at the end of a stack counts, a name
# that only begins with a marker's doesn't, and an unseen name reads zero
{ pkgs, runner }:
let
  source = "${builtins.storeDir}/11111111111111111111111111111111-source";
  folded = pkgs.writeText "profile.folded" ''
    ${source}/src/ownerships/engine.nix:10:5:resolveContext;${source}/src/ownerships/merge.nix:3:3:mergeContributions;${source}/src/ownerships/merge.nix:9:1:mergeNode 7
    ${source}/src/ownerships/engine.nix:10:5:resolveContext;${source}/src/ownerships/engine.nix:10:5:resolveContext 2
    ${source}/src/furnish/core.nix:4:2:indexCollisions;primop sort 4
    ${source}/src/furnish/core.nix:1:1;primop foldl' 5
    ${source}/src/furnish/core.nix:7:1:resolveContextual 3
    ${source}/src/ownerships/merge.nix:3:3:mergeContributions 1
  '';
  expected = ''{"total":22,"inclusive":{"resolveContext":9,"mergeContributions":8,"indexCollisions":4,"absent":0}}'';
  malformed = {
    truncated = "primop sort 1";
    empty = "";
    zero = "primop sort 0\n";
    negative = "primop sort -1\n";
    fraction = "primop sort 1.5\n";
    missing = "primop sort\n";
    leadingZero = "primop sort 01\n";
    emptyFrame = "primop sort;;primop add 1\n";
    badLine = "source.nix:01:2:marker 1\n";
    badColumn = "source.nix:1:0:marker 1\n";
  };
in
pkgs.runCommand "lexicon-bench-reduce" { } ''
  set -euo pipefail
  ${runner}/bin/lexicon-bench reduce ${folded} resolveContext mergeContributions indexCollisions absent > "$out"
  if [[ "$(cat "$out")" != '${expected}' ]]; then
    echo "reduced to $(cat "$out"), expected ${expected}" >&2
    exit 1
  fi
  ${pkgs.lib.concatStrings (
    pkgs.lib.mapAttrsToList (name: content: ''
      if ${runner}/bin/lexicon-bench reduce ${pkgs.writeText "${name}.folded" content} > "${name}.json" 2> "${name}.stderr"; then
        echo "accepted malformed profile ${name}" >&2
        exit 1
      fi
      if [[ -s "${name}.json" ]] || [[ ! -s "${name}.stderr" ]]; then
        echo "malformed profile ${name} lacked its failure evidence" >&2
        exit 1
      fi
    '') malformed
  )}
''
