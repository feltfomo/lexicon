# phase two fills defaults and derived values and builds the provenance map.
# nothing here reports. anything worth saying goes to the next phase as a
# notice
{ lib, field }:
let
  run =
    { kinds }:
    entries:
    let
      kindOf = name: lib.findFirst (kind: kind.name == name) null kinds;

      keyOf = entry: if entry.parent == null then entry.name else "${keyOf entry.parent}.${entry.name}";

      rawOf = entry: if builtins.isAttrs entry.raw then entry.raw else { };

      # what the entity was written as, one contribution at a time, in the
      # order the phase before folded them
      contributionsOf =
        entry:
        if builtins.isList (entry.contributions or null) then
          entry.contributions
        else
          [
            {
              source = "declaration";
              inherit (entry) sourcePath;
              fields = rawOf entry;
            }
          ];

      # precedence is per field and never per entity, so a contribution that
      # lost one key still holds every other key it wrote
      writersOf =
        entry: name:
        builtins.filter (
          contribution: builtins.isAttrs contribution.fields && contribution.fields ? ${name}
        ) (contributionsOf entry);

      locationOf = contribution: name: contribution.sourcePath ++ [ name ];

      valueOf =
        entry:
        let
          kind = kindOf entry.kind;
          raw = rawOf entry;
          parent = if entry.parent == null then null else valueOf entry.parent;

          # a field the author did not write and the descriptions cannot fill
          # is left absent, so the type pass is the one that reports it
          resolved =
            description:
            if raw ? ${description.name} then
              [ (lib.nameValuePair description.name raw.${description.name}) ]
            else if field.isDerived description then
              [
                (lib.nameValuePair description.name (
                  description.derive {
                    self = value;
                    inherit parent;
                  }
                ))
              ]
            else if field.hasDefault description then
              [ (lib.nameValuePair description.name description.default) ]
            else
              [ ];

          value = {
            inherit (entry) name;
          }
          // lib.listToAttrs (lib.concatMap resolved kind.fields);
        in
        value;

      normalized = map (
        entry:
        entry
        // {
          key = keyOf entry;
          path = lib.concatMapStringsSep "." toString entry.sourcePath;
          value = valueOf entry;
        }
      ) entries;

      # one record per field, naming whoever wrote the value that stands and
      # carrying every contribution that lost, in fold order
      provenanceOf =
        entity:
        lib.listToAttrs (
          map (
            name:
            let
              writers = writersOf entity name;
              winner = lib.last writers;
              losing = lib.init writers;
            in
            lib.nameValuePair "${entity.path}.${name}" (
              {
                inherit (winner) source;
                sourcePath = locationOf winner name;
              }
              // lib.optionalAttrs (losing != [ ]) {
                overridden = map (contribution: {
                  inherit (contribution) source;
                  sourcePath = locationOf contribution name;
                }) losing;
              }
            )
          ) (builtins.attrNames (rawOf entity))
        );

      noticesOf =
        entity:
        let
          kind = kindOf entity.kind;
          raw = rawOf entity;
        in
        lib.concatMap (
          description:
          lib.optional (field.isDerived description && raw ? ${description.name}) {
            code = "derived-override";
            args = {
              at = entity.sourcePath ++ [ description.name ];
              context = {
                field = description.name;
                value = raw.${description.name};
              };
            };
          }
        ) kind.fields
        # the reader is taken to the line that did not take effect, and the
        # writer that stands is named there
        ++ lib.concatMap (
          name:
          let
            writers = writersOf entity name;
            winner = lib.last writers;
          in
          map (loser: {
            code = "source-override";
            args = {
              at = locationOf loser name;
              context = {
                field = name;
                inherit (winner) source;
              };
            };
          }) (lib.init writers)
        ) (builtins.attrNames raw);
    in
    {
      registry = {
        entities = normalized;
      };
      provenance = lib.foldl' (acc: entity: acc // provenanceOf entity) { } normalized;
      notices = lib.concatMap noticesOf normalized;
    };
in
{
  inherit run;
}
