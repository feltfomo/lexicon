{ paperkite }:
{
  # the declaration emits nixos, so its module belongs in the NixOS graph
  imports = [ paperkite.nixos ];
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
