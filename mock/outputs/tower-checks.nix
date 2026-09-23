# an output declaration written for one host. the host is named as a string,
# which is the name the attribute path ends up under and the name a mistyped
# one is suggested against
#
# every step here is deliberately trivial. nix flake check builds the checks
# of the system it runs on, so a declared check that reached for a toolchain
# or a network would turn the strongest gate in the tree into one nobody runs
{ host, ... }:
host "tower" {
  checks = {
    host-declares-its-own = {
      steps = [
        {
          name = "compare";
          run = "test tower = tower";
        }
        {
          name = "seal";
          run = "mkdir -p $out";
        }
      ];
    };
  };
}
