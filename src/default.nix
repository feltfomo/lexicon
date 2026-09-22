# every subsystem takes lib and fx from here. two nix-effects instances make
# types that never compare equal
{ lib, fx }:
let
  version = "0.0.0";

  # every other subsystem reports through it
  krisis = import ./krisis { inherit lib fx; };

  # the identity registry. its doors are re-exported at the root
  registry = import ./koseki { inherit lib fx krisis; };

  arrows = import ./arrows.nix { inherit lib fx; };

  # the declaration layer sits above the registry and is handed it, so it
  # never reaches for where the registry lives
  kata = import ./kata {
    inherit
      lib
      fx
      krisis
      arrows
      ;
    engine = registry;
  };

  # above every subsystem and before any walk. it reads registrations and
  # names none of them
  settings = import ./settings {
    inherit
      lib
      fx
      krisis
      arrows
      ;
    inherit (registry) t;
  };

  # emission is handed the block registry and the constructors, so it reads
  # compiled halves without reaching for where the declaration layer lives
  emission = import ./emit {
    inherit
      lib
      fx
      krisis
      arrows
      ;
    inherit (registry) t;
    inherit (kata.internal) blocks construct;
    claimKeys = kata.internal.claims.keys;
    knownNames = kata.internal.resolve.Known;
    Prepared = kata.internal.types.Prepared;
    text = kata.internal.vocabulary.text;
  };

  # the read-only view is handed the registries it reports on, so it restates
  # no kind, no block and no backend of its own
  introspection = import ./introspect.nix {
    inherit
      lib
      fx
      arrows
      version
      ;
    inherit (registry) t;
    inherit (kata.internal) kinds blocks construct;
    claimKeys = kata.internal.claims.keys;
  };

  # this is the one place a subsystem is named, and the door is handed the
  # list it loads and the arrows it runs after
  door = import ./configure.nix {
    inherit
      fx
      krisis
      settings
      library
      ;

    emission = emission.run;

    # the arrow the caller runs the walked set through, so a contribution
    # handed in at the door reaches the layer below
    preparation = kata.run;

    registrations = [ kata.settings ];

    walk =
      root: slices:
      kata.walk {
        configuration = root;
        settings = slices.${kata.settings.name};
      };
  };

  # a settings file is handed this whole value under the name library, and
  # the walked set never reaches it
  library = {
    inherit
      lib
      fx
      krisis
      kata
      settings
      emission
      introspection
      version
      ;

    inherit (door) configure;

    inherit (introspection) introspect;

    # the drop-in borrows the argument names of the placement it shares a
    # projection with, and this is where that placement is named
    inherit ((emission.aspectFor emission.backends.byName.den)) toDenAspect;
  }
  // registry;
in
library
