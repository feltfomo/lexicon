{ host, lexicon, ... }:
host {
  includes = [ lexicon.scribe ];

  declare = {
    system = "x86_64-linux";
    stateVersion = "25.05";
    hardware = "laptop";
  };
}
