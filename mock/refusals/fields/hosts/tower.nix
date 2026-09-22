# the account's shell field is spelled wrong
{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    stateVersion = "25.05";
    hardware = "desktop";

    users.warden.shel = "/run/current-system/sw/bin/fish";
  };
}
