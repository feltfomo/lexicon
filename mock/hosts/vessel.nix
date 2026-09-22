{ host, lexicon, ... }:
host {
  includes = [ lexicon.warden ];

  declare = {
    system = "x86_64-linux";
    stateVersion = "25.05";
    hardware = "virtual";
  };
}
