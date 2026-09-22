{ entry, ... }:
entry {
  furnish = {
    hosts = [ "tower" ];

    files = [
      {
        src = "/configs/desk/monitors-tower.conf";
        dest = ".config/desk/monitors.conf";
      }
    ];
  };
}
