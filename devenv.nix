{
  config,
  pkgs,
  ...
}:
let
  root = config.devenv.root;
  praxis = verb: {
    exec = "lexicon-praxis --non-interactive ${verb}";
    cwd = root;
  };
in
{
  packages = with pkgs; [
    bashInteractive
    golangci-lint
    shellcheck
    marksman
    nix-unit
    deadnix
    gofumpt
    rustfmt
    clippy
    nixfmt
    statix
    cargo
    delve
    gopls
    rustc
    shfmt
    taplo
    nixd
    git
    nix
    go
    jq
  ];

  # the flake owns the praxis project and its pins, so the shell runs it from the working tree
  scripts.lexicon-praxis = {
    exec = ''exec nix run "path:${root}#lexicon-praxis" -- "$@"'';
    description = "run the Lexicon praxis command project";
  };

  # the verbs delegate to praxis, which owns their commands, the gate order and the gate lock
  tasks = {
    "lexicon:fmt" = praxis "fmt";
    "lexicon:check" = praxis "check";
    "lexicon:test" = praxis "test";
    "lexicon:gate" = praxis "gate";
    "lexicon:bench" = praxis "bench";
  };

  enterShell = ''
    echo "lexicon dev shell. Commands: devenv tasks run lexicon:fmt lexicon:check lexicon:test lexicon:gate lexicon:bench, lexicon-praxis"
  '';

  enterTest = ''
    devenv tasks run lexicon:gate
  '';
}
