{ entry, ... }:
entry {
  nixos = {
    services.dbus.enable = true;
  };

  furnish.files = [
    {
      src = "/configs/desk/desk.conf";
      dest = ".config/desk/desk.conf";
    }
  ];

  theme = {
    id = "desk";
    output = ".config/desk/colors.conf";
    reload = "pkill -USR1 desk";
    renderers.palette.source = "/configs/desk/colors.conf";
  };
}
