{ declaration }:
{
  # file-producing declarations expose the NixOS module that imports Furnish
  imports = [ declaration.nixos ];
  # activation remains an explicit host choice even though declarations are lowered automatically
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
