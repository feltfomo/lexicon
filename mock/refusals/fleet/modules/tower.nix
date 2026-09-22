# the machine the facet beside it meant to name
{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    stateVersion = "25.05";
    hardware = "desktop";
    users = { };
  };
}
