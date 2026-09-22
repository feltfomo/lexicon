# construction is inert. a constructor reshapes what it was handed and
# decides nothing, so a value that is wrong is still a value the reporter
# can name and place
{
  lib,
  kinds,
  types,
}:
let
  tag = "__kata";

  tagged = types.Tagged tag;
  sound = types.Construction tag;

  kindNamed = name: lib.findFirst (kind: kind.name == name) null kinds;

  # a kind with a declare writes its fields behind that key; every other
  # kind writes its blocks straight into the spec. the spec is kept whole
  # beside them so a key nobody reads can still be named
  of =
    origin: name: spec:
    let
      given = if builtins.isAttrs spec then spec else { };
      described = kindNamed name;
      wrapped = described != null && described.declare;
    in
    {
      ${tag} = {
        kind = name;
        inherit origin spec;
        includes = given.includes or [ ];
        declare = if wrapped then given.declare or { } else { };
        blocks = if wrapped then { } else builtins.removeAttrs given [ "includes" ];
      };
    };

  # the constructors come off the registry, so a new kind is registry data
  from =
    origin:
    lib.listToAttrs (map (kind: lib.nameValuePair kind.name (of origin kind.name)) kinds)
    // {
      of = of origin;
    };

  read = value: value.${tag};
in
{
  inherit
    tag
    of
    from
    read
    ;

  isTagged = value: tagged.check value;

  isSound = value: sound.check value;
}
