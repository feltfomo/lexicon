{
  projectRootFile = "flake.nix";
  settings.global.excludes = [ "docs/*" ];
  programs.nixfmt.enable = true;
  programs.rustfmt.enable = true;
  programs.taplo.enable = true;
  programs.statix.enable = true;
}
