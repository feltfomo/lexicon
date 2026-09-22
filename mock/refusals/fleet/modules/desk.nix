# the claim names a machine that is spelled wrong
{ entry, ... }:
entry {
  furnish = {
    hosts = [ "towor" ];

    files = [
      {
        src = "/configs/desk/desk.conf";
        dest = ".config/desk/desk.conf";
      }
    ];
  };
}
