# how a block's outputs sit under the standard attribute they land in. nix
# does not agree with itself about the shape of an output attribute, some
# hold a set of names and some hold one value, so a table of attribute names
# could not say which of the two a block takes
#
# the two shapes are declared because the declaration is load bearing at the
# reader, where the case analysis is checked against it and reports both an arm
# that is no declared shape and a shape that has no arm. at the writing site
# what refuses a third shape is this module exporting exactly two builders
{ fx }:
let
  H = fx.types.hoas;

  Placement = H.datatype "Placement" [
    (H.con "byName" [ (H.field "attribute" H.string) ])
    (H.con "only" [ (H.field "attribute" H.string) ])
  ];

  # the builders below are the only route to a placement, and the constructor
  # name each writes is what the case analysis checks against the declaration
  #
  # building these through the declared constructors was tried on nix-effects
  # 0.16.0 and every value so built failed in the pipeline with "extract: Sum
  # value expected sum payload, got VDescCon"
  held = constructor: attribute: {
    _con = constructor;
    inherit attribute;
  };
in
{
  inherit Placement;

  # the outputs land keyed by the name each was declared under
  byName = held "byName";

  # the one output a block declared lands directly under the system
  only = held "only";
}
