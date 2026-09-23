# a check named after each walked entry proves one knot spans both trees,
# since the names come off the walked set. steps stay trivial so the flake
# gate pulls in no toolchain or network.
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

  # greet reads its arguments and its exit status off what it was handed, and
  # check is named after a built-in so the collision has something to report
  commands = {
    greet = {
      steps = [
        {
          name = "write";
          run = ''
            mkdir -p $out/bin
            printf '#!/bin/sh\nif [ "$1" = "--refuse" ]; then exit 3; fi\necho greetings "$@"\n' > $out/bin/greet
            chmod +x $out/bin/greet
          '';
        }
      ];
    };

    check = {
      steps = [
        {
          name = "write";
          run = ''
            mkdir -p $out/bin
            printf '#!/bin/sh\necho the declared check ran\n' > $out/bin/check
            chmod +x $out/bin/check
          '';
        }
      ];
    };
  };

  devShells = {
    default = {
      packages = [ "jq" ];
    };
  };

  # the fleet declares one formatter and it reaches formatter.<system>, which
  # is the whole of what a configuration outside lexicon has to write for nix
  # fmt to find it. the program is a name in the package set because that is
  # all a declaration can reach
  fmt = {
    tree = {
      program = "nixfmt";
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
