{
  projectRootFile = "flake.nix";
  # the check copies this tree and runs git init in it, so git metadata and nested
  # checkouts such as agent worktrees stay out, as git leaves them out of the real tree
  projectRoot = builtins.path {
    name = "source";
    path = ./.;
    filter =
      path: type:
      baseNameOf path != ".git" && !(type == "directory" && builtins.pathExists "${path}/.git");
  };
  programs.nixfmt.enable = true;
  programs.rustfmt.enable = true;
  programs.taplo.enable = true;
  programs.statix.enable = true;
}
