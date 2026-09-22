# a claim at the top of a block is the one thing that decides which host a
# facet reaches
{ entry, ... }:
entry {
  furnish = {
    hosts = [ "workstation" ];
    files = [
      {
        src = "/configs/desktop/desktop.conf";
        dest = ".config/desktop/desktop.conf";
      }
    ];
  };
}
