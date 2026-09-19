{ helix, ... }:
{
  # the same declaration's Home Manager side carries its package and imports
  imports = [ helix.homeManager ];
  home.username = "river";
  home.homeDirectory = "/home/river";
  home.stateVersion = "26.05";
}
