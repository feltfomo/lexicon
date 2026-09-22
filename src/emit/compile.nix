# one compiler and one wrapper. a backend decides what it binds before the
# module system sees the result
{
  lib,
  t,
  arrows,
  blocks,
  placement,
}:
let
  inherit (arrows) sum;

  Placement = sum {
    classed = t.Attrs;
    carried = t.Any;
  };

  # a block with no arm in the table surfaces where its placement is read
  arms = placement {
    classed = class: {
      classes = [ class ];
      place =
        compiled:
        Placement.inject.classed {
          inherit class compiled;
        };
    };

    carried = {
      classes = [ ];
      place = compiled: Placement.inject.carried compiled;
    };
  };

  classNames = lib.unique (lib.concatMap (arm: arm.classes) (builtins.attrValues arms));

  # the independent half is read once per declaration and every backend
  # reuses it. on all four registered blocks the dependent half is the
  # identity, and on a function-form interior deepSeq stops at weak head
  # normal form, so the independent half yields the record and the shape of
  # its module list. measured 2026-09-21
  compiledOf =
    name: interior: arms.${name}.place (blocks.byName.${name}.compile.independent interior);

  halvesOf =
    interiors:
    lib.listToAttrs (
      lib.concatMap (
        name:
        blocks.Registration.case {
          known = block: [ (lib.nameValuePair block (compiledOf block interiors.${block})) ];
          unregistered = _: [ ];
        } (blocks.classify name)
      ) (builtins.attrNames interiors)
    );

  # the module system injects _module.args only for a name a module
  # declares, so the wrapper names its arguments statically and a name the
  # backend binds is applied here and struck off the advertised set. the
  # dependent half is applied inside the closure and its result placed under
  # imports. measured 2026-09-21
  wrap =
    {
      context,
      bound,
      block,
      compiled,
    }:
    let
      advertised = builtins.filter (name: !(bound ? ${name})) context;
    in
    lib.setFunctionArgs (ctx: {
      imports = (block.compile.dependent (ctx // bound) compiled).modules;
    }) (lib.genAttrs advertised (_: false));

  # what the backend binds is one definition for the whole evaluation,
  # contributed as a module of its own, so the count of interiors on a host
  # decides nothing about it
  #
  # two interiors on one host died with "the option _module.args.host is
  # defined multiple times". 2026-09-21
  bindings = bound: lib.optional (bound != { }) { _module.args = bound; };

  # the projection both placements share
  project =
    {
      context,
      bound,
      interiors,
    }:
    let
      placed = halvesOf interiors;
      names = builtins.attrNames placed;

      moduleFor =
        class:
        lib.concatMap (
          name:
          Placement.case {
            classed =
              held:
              lib.optional (held.class == class) (wrap {
                inherit context bound;
                block = blocks.byName.${name};
                inherit (held) compiled;
              });
            carried = _: [ ];
          } placed.${name}
        ) names;
    in
    {
      classes = lib.genAttrs classNames moduleFor;

      carried = lib.listToAttrs (
        lib.concatMap (
          name:
          Placement.case {
            classed = _: [ ];
            carried = data: [ (lib.nameValuePair name data) ];
          } placed.${name}
        ) names
      );
    };
in
{
  inherit
    Placement
    classNames
    halvesOf
    wrap
    bindings
    project
    ;
}
