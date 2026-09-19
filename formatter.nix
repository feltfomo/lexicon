# nix is the only language in the tree. the coordinator's rust lives in its
# own repo
{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  settings.global.excludes = [
    "docs/*"
    "LICENSE"
    "*.lock"
  ];

  programs = {
    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };
    deadnix.enable = true;
    statix.enable = true;
  };
}
