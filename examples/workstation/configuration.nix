{ setup }:
_:
let
  alice = setup.forUser "alice";
in
{
  imports = [ alice.nixos ];
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "workstation";
  users.users.alice.isNormalUser = true;
  lexicon.furnish.enable = true;
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.alice = {
      imports = [ alice.homeManager ];
      home.username = "alice";
      home.homeDirectory = "/home/alice";
      home.stateVersion = "26.05";
    };
  };
  system.stateVersion = "26.05";
}
