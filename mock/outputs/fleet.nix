# the outputs this fleet declares, written in a file the walk reads. the
# check named after each walked entry is what proves one knot spans both
# trees, because the names come off the walked set itself and a file under
# this tree only sees the ones from the other tree if that set is the union.
# only the names are read, never what an entry built
#
# every step here is deliberately trivial. nix flake check builds the checks
# of the system it runs on, so a declared check that reached for a toolchain
# or a network would turn the strongest gate in the tree into one nobody runs
{ fleet, lexicon, ... }:
let
  sealed = {
    steps = [
      {
        name = "seal";
        run = "mkdir -p $out";
      }
    ];
  };
in
fleet {
  checks = {
    fleet-declares-hostless = sealed;
  }
  // builtins.listToAttrs (
    map (name: {
      name = "walk-reached-${name}";
      value = sealed;
    }) (builtins.attrNames lexicon)
  );

  devShells = {
    default = {
      packages = [ "jq" ];
    };
  };

  packages = {
    greeting = {
      steps = [
        {
          name = "write";
          run = "mkdir -p $out && echo hello > $out/greeting";
        }
      ];
    };
  };
}
