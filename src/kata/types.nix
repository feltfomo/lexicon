# the shape of a constructed value and of what leaves this layer. the shapes
# a walked file carries belong to the walk and arrive as an argument, and the
# two a declaration is written in terms of are handed on from here so a
# caller reaching through kata still finds them
{
  fx,
  t,
  walk,
}:
let
  # the tag payload. the constructors write every key, so a failure here is
  # a caller's spec landing on the wrong field
  Payload = t.bless (
    fx.types.Record {
      kind = t.String;
      origin = t.nullOr t.String;
      includes = t.listOf t.Any;
      declare = t.Attrs;
      blocks = t.Attrs;
      spec = t.Any;
    }
  );

  # decides which diagnostic a value gets before its payload is worth
  # reading
  Tagged = tag: t.refined "Tagged" t.Attrs (value: value ? ${tag});

  Construction = tag: t.refined "Construction" (Tagged tag) (value: Payload.check value.${tag});

  # the one path segment a diagnostic about a whole declaration is written
  # at. the walk is the only thing that knows the file
  Place = t.refined "Place" (t.listOf t.String) (value: builtins.length value == 1);

  # one place per declaration, keyed by the name it landed under
  Origins = t.refined "OriginIndex" t.Attrs (
    value: builtins.all (name: Place.check value.${name}) (builtins.attrNames value)
  );

  # what the fold hands resolution. a diagnostic about a claim names the
  # file the claim was written in, which is what the places carry
  Indexed = t.bless (
    fx.types.Record {
      declaration = t.Attrs;
      origins = Origins;
    }
  );

  # what leaves kata and what emission takes, a built registry and the
  # claims resolved against it
  Prepared = t.bless (
    fx.types.Record {
      registry = t.Attrs;
      claims = t.Attrs;
    }
  );
in
{
  inherit
    Payload
    Tagged
    Construction
    Place
    Origins
    Indexed
    Prepared
    ;

  inherit (walk) Relative Name;
}
