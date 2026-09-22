# the shape of a constructed value and of everything the walk carries. the
# same description answers the fast boolean question and, on the effectful
# path, blames the field that failed
{
  lib,
  fx,
  t,
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

  # every path the walk carries is written from the configuration root
  Relative = t.refined "RelativePath" t.String (value: value != "" && !lib.hasPrefix "/" value);

  Name = t.refined "EntryName" t.String (fx.types.matching "[^./]+");

  # a file the tree offered. it carries no name, because a name is what
  # surviving the exclusion list earns it
  Discovered = t.bless (
    fx.types.Record {
      root = Relative;
      relative = Relative;
      origin = Relative;
    }
  );

  Screened = t.bless (
    fx.types.Record {
      root = Relative;
      relative = Relative;
      origin = Relative;
      name = Name;
    }
  );

  # the import path is rebuilt from the origin, so nothing downstream of here
  # holds an absolute path
  Resolved = t.bless (
    fx.types.Record {
      name = Name;
      origin = Relative;
    }
  );

  Clash = t.bless (
    fx.types.Record {
      name = Name;
      origins = t.listOf Relative;
    }
  );

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
    Relative
    Name
    Discovered
    Screened
    Resolved
    Clash
    Place
    Origins
    Indexed
    Prepared
    ;
}
