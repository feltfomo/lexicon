# the constructors a file under a telos root is handed. construction is
# inert, so an output declared wrong is still a value the assembly can name
# and place rather than a failure at import
{
  lib,
  kinds,
  types,
}:
let
  tag = "__telos";

  sound = types.Declaration tag;

  # a sourced kind takes the name it was written for first, and a kind that
  # names none writes null there rather than leaving the field off
  of =
    origin: described:
    if described.sourced then
      source: spec: {
        ${tag} = {
          kind = described.name;
          inherit origin source spec;
        };
      }
    else
      spec: {
        ${tag} = {
          kind = described.name;
          source = null;
          inherit origin spec;
        };
      };

  # the constructors come off the registry, so a new kind is registry data
  from = origin: lib.listToAttrs (map (kind: lib.nameValuePair kind.name (of origin kind)) kinds);

  read = value: value.${tag};
in
{
  inherit
    tag
    of
    from
    read
    ;

  isSound = value: sound.check value;
}
