let
  root = toString ../.;
  included = [
    ".gitignore"
    "README.md"
    "flake.nix"
    "flake.lock"
    "formatter.nix"
    "src"
    "tests"
    "examples"
    "docs"
  ];
in
builtins.path {
  name = "lexicon-source";
  path = ../.;
  # reject excluded directories before nix descends into them
  filter =
    path: _type:
    let
      relative = builtins.substring (builtins.stringLength root + 1) (-1) path;
      parts = builtins.filter builtins.isString (builtins.split "/" relative);
    in
    path == root
    || (
      builtins.elem (builtins.head parts) included
      && !builtins.any (
        part:
        builtins.elem part [
          ".git"
          ".notion-sync"
          "old-docs"
        ]
      ) parts
      && relative != "src/praxis/runtime/target"
    );
}
