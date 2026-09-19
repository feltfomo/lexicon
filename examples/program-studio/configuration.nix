{ helix }:
{
  # the combined declaration's NixOS side includes settings and file publication
  imports = [ helix.nixos ];
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
