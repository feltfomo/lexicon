# the shape of every file a walk carries, from what a tree offered to what
# the knot is tied over. the same description answers the fast boolean
# question and, on the effectful path, blames the field that failed
{
  lib,
  fx,
  t,
}:
let
  # every path a walk carries is written from the configuration root
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
  # holds an absolute path. the root rides along because the constructors a
  # file is handed are the ones of the subsystem whose root offered it
  Resolved = t.bless (
    fx.types.Record {
      name = Name;
      origin = Relative;
      root = Relative;
    }
  );

  # the root is the one the first file in the group came from, and it decides
  # whose words the refusal is written in
  Clash = t.bless (
    fx.types.Record {
      name = Name;
      root = Relative;
      origins = t.listOf Relative;
    }
  );
in
{
  inherit
    Relative
    Name
    Discovered
    Screened
    Resolved
    Clash
    ;
}
