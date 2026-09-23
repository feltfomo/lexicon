# the shapes the assembly carries between its stages, and the shape a walked
# file writes behind the tag. each one is declared here so a stage boundary
# is checked rather than trusted
{
  fx,
  t,
}:
let
  Name = t.refined "OutputName" t.String (value: value != "");

  # what a constructor writes. a kind that names its source carries the name
  # it was written for, and a kind that names none carries null
  Declared = t.bless (
    fx.types.Record {
      kind = Name;
      origin = t.nullOr t.String;
      source = t.nullOr Name;
      spec = t.Any;
    }
  );

  # decides which diagnostic a value gets before its payload is worth
  # reading
  Tagged = tag: t.refined "Tagged" t.Attrs (value: value ? ${tag});

  Declaration = tag: t.refined "Declaration" (Tagged tag) (value: Declared.check value.${tag});

  # where one block's interior was written and the system the outputs in it
  # land under. a host declaration and a fleet declaration differ only in the
  # kind they came from, so one shape carries both
  Site = t.bless (
    fx.types.Record {
      kind = Name;
      source = Name;
      system = Name;
      block = Name;
      interior = t.Any;
    }
  );

  # one declared output after the independent half has read it. the payload is
  # a description, which is what a kernel checked record may hold, and never
  # the thing the description builds
  Described = t.bless (
    fx.types.Record {
      system = Name;
      source = Name;
      block = Name;
      output = Name;
      described = t.Any;
    }
  );

  Sites = t.listOf Site;

  Descriptions = t.listOf Described;
in
{
  inherit
    Name
    Declared
    Tagged
    Declaration
    Site
    Described
    Sites
    Descriptions
    ;
}
