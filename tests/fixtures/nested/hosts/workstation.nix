# the host says nothing about where a user lands. it includes one, and the
# kind registry decides the rest
{ host, lexicon, ... }:
host {
  includes = [ lexicon.ada ];

  declare = {
    system = "x86_64-linux";
  };
}
