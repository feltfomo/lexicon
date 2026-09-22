# the two shapes every subsystem above the kernel keeps reaching for. both are
# built from one description, so the thing that declares a structure is also
# the thing that eliminates it
{ lib, fx }:
let
  # the kernel's seq keeps only the last result, and the stream combinators
  # read each step straight off a pure computation, so neither one carries an
  # arrow that sends. the results ride the kernel's own arrow chain instead.
  # read against nix-effects core-api/kernel and its stream/reduce source at
  # 0.5.2, docs buildhash 1xxh55icdl0xpinnn69wz20wykrhjwds
  traverse =
    arrow: items:
    fx.pipe (fx.pure [ ]) (
      map (item: gathered: fx.map (result: gathered ++ [ result ]) (arrow item)) items
    );

  # a tagged sum, its injections and its case analysis, all read off the same
  # schema. nix decides no case analysis exhaustive, so an arm the schema
  # declares and the caller omits surfaces where it is dispatched
  sum =
    schema:
    let
      arm = arms: lib.mapAttrs (tag: _: arms.${tag}) schema;
    in
    {
      inject = lib.mapAttrs (tag: _: value: {
        _tag = tag;
        inherit value;
      }) schema;

      case = arms: value: (arm arms).${value._tag} value.value;
    };
in
{
  inherit traverse sum;
}
