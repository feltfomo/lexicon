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

  # the trees are read once for every subsystem that named one, so the shapes
  # and the codes a walk carries belong here and are handed to whoever the
  # walk speaks for
  walking = import ./walk {
    inherit
      lib
      fx
      krisis
      arrows
      ;
    inherit (registry) t;
  };

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
    walk = walking;
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

  # the output layer, handed the reporter it speaks diagnostics with, the
  # block contract and the registry factory. it builds its own registry over
  # its own kinds and under its own namespace, so it copies none of the
  # registration machinery and names no declaration layer path
  telos = import ./telos {
    inherit lib fx krisis;
    inherit (registry) t;
    inherit (kata.internal) block;
    inherit (kata.internal.blocks) factory;
    walk = walking;
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

    # the arrow the caller runs the walked set through. the knot spans every
    # root, so the declaration layer is handed the slice its own roots
    # offered rather than the union
    preparation =
      { owned, ... }@opened:
      values:
      kata.run (builtins.removeAttrs opened [ "owned" ]) (
        builtins.intersectAttrs owned.${kata.settings.name} values
      );

    registrations = [
      kata.settings
      telos.settings
    ];

    walk =
      root: slices:
      walking.run {
        configuration = root;
        subsystems = [
          {
            inherit (kata.settings) name;
            inherit (slices.${kata.settings.name}) roots exclude;
            emit = kata.internal.vocabulary.emit;
            constructorsFor = kata.from;
          }
          {
            inherit (telos.settings) name;
            inherit (slices.${telos.settings.name}) roots exclude;
            emit = telos.vocabulary.emit;
            constructorsFor = telos.internal.construct.from;
          }
        ];
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
      telos
      version
      ;

    walk = walking;

    inherit (door) configure;

    inherit (introspection) introspect;

    # the drop-in borrows the argument names of the placement it shares a
    # projection with, and this is where that placement is named
    inherit ((emission.aspectFor emission.backends.byName.den)) toDenAspect;
  }
  // registry;
in
library
