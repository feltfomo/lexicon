# a home carrying a machine-wide service
{ home, ... }:
home {
  homeManager = {
    programs.git.enable = true;
  };

  nixos = {
    services.dbus.enable = true;
  };
}
