# what a new machine is copied from
{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    stateVersion = "25.05";
    hardware = "generic";
    users = { };
  };
}
