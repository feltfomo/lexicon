{ lexicon, ... }:
{
  # bind the runtime before loading direct file declarations
  imports = [
    (lexicon.lib.furnishRuntime { })
    ./furnish.nix
  ];

  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
