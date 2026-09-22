# every type a declaration is checked against is minted here and carries the
# instance token. a type built by another instance is reported, not silently
# trusted
{ fx, token }:
let
  stamp = "_lexInstance";

  bless = type: type // { ${stamp} = token; };

  # the only comparison of the token in the subsystem
  blessed = type: builtins.isAttrs type && (type.${stamp} or null) == token;

  # fx reads its own fields off the type record; the stamp never crosses over
  strip = type: builtins.removeAttrs type [ stamp ];

  t = {
    inherit bless;

    Any = bless fx.types.Any;
    Attrs = bless fx.types.Attrs;
    Bool = bless fx.types.Bool;
    Int = bless fx.types.Int;
    String = bless fx.types.String;

    listOf = inner: bless (fx.types.ListOf (strip inner));

    refined =
      name: base: predicate:
      bless (fx.types.refined name (strip base) predicate);

    nullOr =
      inner:
      bless (
        fx.types.refined "Optional${inner.name}" fx.types.Any (
          value: value == null || (strip inner).check value
        )
      );
  };
in
{
  inherit t blessed strip;
}
