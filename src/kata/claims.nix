# a claim is a facet, recognised only where a block declared it can appear. a
# claim-shaped value at an undeclared route is ordinary block data and is left
# alone
{
  lib,
  fx,
  vocabulary,
  kinds,
}:
let
  inherit (vocabulary) emit;

  # the kinds that already hold their own schema are the ones a claim names, so
  # the keys come off the kind registry
  keys = map (kind: kind.collection) (builtins.filter (kind: kind.declare) kinds);

  claimed =
    at: value:
    map (
      key:
      if builtins.isList value.${key} && builtins.all builtins.isString value.${key} then
        fx.pure null
      else
        emit.malformed-claim {
          at = at ++ [ key ];
          context = {
            claim = key;
          };
        }
    ) (builtins.filter (key: value ? ${key}) keys);

  unwalkable =
    name: at:
    emit.unwalkable-claim-route {
      inherit at;
      context = {
        block = name;
      };
    };

  # the descent is defined over the structural part of an interior. a node the
  # route has to pass through only exists once the module arguments do, so the
  # route itself is the defect and not the value under it. a node the route
  # reaches that is the wrong shape to walk is left alone, because the block's
  # own validator reports the shape of its interior
  descend =
    name: at: route: value:
    if builtins.isFunction value then
      unwalkable name at
    else if route == [ ] then
      fx.seq (if builtins.isAttrs value then claimed at value else [ ])
    else if !builtins.isAttrs value then
      fx.pure null
    else
      let
        key = builtins.head route;
        rest = builtins.tail route;
        held = value.${key} or null;
      in
      if held == null then
        fx.pure null
      else if builtins.isFunction held then
        unwalkable name (at ++ [ key ])
      else if !builtins.isList held then
        fx.pure null
      else
        fx.seq (
          lib.imap0 (
            index: entry:
            descend name (
              at
              ++ [
                key
                index
              ]
            ) rest entry
          ) held
        );

  check =
    {
      block,
      value,
      at,
    }:
    fx.seq (map (route: descend block.name at route value) block.claimable);
in
{
  inherit keys check;
}
