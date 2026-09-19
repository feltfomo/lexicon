{ theme }:
{
  # a file-producing theme emits the NixOS side even without a nixos field
  imports = [ theme.nixos ];
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
