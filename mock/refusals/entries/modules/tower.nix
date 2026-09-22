# the system field is written outside declare
{ host, ... }:
host {
  system = "x86_64-linux";

  declare = {
    stateVersion = "25.05";
    hardware = "desktop";
    users = { };
  };
}
