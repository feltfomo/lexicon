{ system }:
# this fixture proves the adapter boundary without instantiating a Den host
{
  hosts.${system}.studio = {
    dimensions = { };
    users.river = { };
    aspect = throw "the Program Den example forced host aspect internals";
    instantiate = throw "the Program Den example forced host instantiation";
  };
  lib = throw "the Program Den example forced den.lib";
}
