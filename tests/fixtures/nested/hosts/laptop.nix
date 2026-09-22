# the second host includes the same file, and the user lands on both
{ host, lexicon, ... }:
host {
  includes = [ lexicon.ada ];

  declare = {
    system = "aarch64-linux";
  };
}
