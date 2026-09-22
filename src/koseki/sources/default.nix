# the sources key. a source hands over entities, a rename map decides which
# name each one lands on, and every name a second thing claims is reported
{ lib, krisis }:
let
  adapter = import ./den.nix { inherit lib; };

  adapters = {
    den = adapter.read;
  };

  # the public way to hand a den configuration over. the name keys inherited
  # and travels in every provenance record, and the rename map rides along
  # with the reading
  den =
    configuration: config:
    let
      held = if builtins.isAttrs config then config else { };
    in
    {
      source = adapter.read configuration // lib.optionalAttrs (held ? name) { inherit (held) name; };
      renames = held.renames or { };
    };

  isRecord = value: builtins.isAttrs value && value ? ok && value ? entities;

  wrapped = value: builtins.isAttrs value && value ? source;

  # the key is a list and one entry is one source
  entriesOf =
    written:
    if builtins.isList written then
      lib.imap0 (index: held: {
        at = [
          "sources"
          index
        ];
        inherit held;
      }) written
    else
      [ ];

  unwrap =
    held:
    if wrapped held then
      {
        record = held.source;
        renames = held.renames or { };
      }
    else
      {
        record = held;
        renames = { };
      };

  invalidValue = at: field: expected: value: notes: {
    code = "invalid-value";
    args = {
      inherit at notes;
      context = {
        inherit field value;
        type = expected;
      };
    };
  };

  # the source's own key for a host, which is the only thing that tells two
  # hosts of one name apart
  sourceKeyOf = entity: lib.concatStringsSep "/" (lib.take 2 entity.path);

  systemOf = entity: builtins.head entity.path;

  takes = "lexicon.source.den takes the evaluated den configuration, the attrset carrying hosts";

  read =
    { kinds, declaration }:
    let
      written = if builtins.isAttrs declaration then declaration.sources or null else null;

      kindNamed = name: lib.findFirst (kind: kind.name == name) null kinds;

      declaredNames =
        name:
        let
          described = kindNamed name;
          held = if described == null then null else declaration.${described.collection} or null;
        in
        if builtins.isAttrs held then builtins.attrNames held else [ ];

      readEntry =
        entry:
        let
          inherit (unwrap entry.held) record renames;

          label = if builtins.isAttrs record then record.name or "den" else "den";

          wellShaped = isRecord record;

          renamesShaped =
            builtins.isAttrs renames
            && builtins.all (key: builtins.isString renames.${key}) (builtins.attrNames renames);

          usable = wellShaped && record.ok && renamesShaped;

          # the adapter names the kind of its top-level entities, and a
          # child names the entity it belongs to
          rootKind = if wellShaped then record.kind or "entity" else "entity";

          roots = if wellShaped then builtins.filter (entity: entity.parent == null) record.entities else [ ];

          children =
            if wellShaped then builtins.filter (entity: entity.parent != null) record.entities else [ ];

          known = map sourceKeyOf roots;

          flakeNotes = [
            "this looks like a flake, and den keeps its hosts in module configuration"
            "export them from the den consumer with flake.den = config.den and pass inputs.<flake>.den"
          ];

          shapeProblems =
            lib.optional (!wellShaped) (
              invalidValue entry.at "sources" "a source built with lexicon.source.den" (builtins.typeOf record) [
                takes
              ]
            )
            ++ lib.optional (wellShaped && !record.ok) (
              invalidValue entry.at "sources" record.wanted record.got (
                if record.flake then flakeNotes else [ takes ]
              )
            )
            ++ lib.optional (wellShaped && record.ok && !renamesShaped) (
              invalidValue (
                entry.at ++ [ "renames" ]
              ) "renames" "an attrset of source keys to names" (builtins.typeOf renames) [ ]
            );

          renameKeys = if renamesShaped then builtins.attrNames renames else [ ];

          validKeys = builtins.filter (key: builtins.elem key known) renameKeys;

          strayKeys = builtins.filter (key: !builtins.elem key known) renameKeys;

          targetOf = entity: renames.${sourceKeyOf entity} or null;

          finalOf =
            entity:
            let
              target = targetOf entity;
            in
            if target == null then entity.name else target;

          rootAt = key: lib.findFirst (entity: sourceKeyOf entity == key) null roots;

          staying = map (entity: entity.name) (builtins.filter (entity: targetOf entity == null) roots);

          unknownProblems = map (key: {
            code = "unknown-rename";
            args = {
              at = entry.at ++ [
                "renames"
                key
              ];
              context = {
                rename = key;
                source = label;
              };
              notes =
                let
                  nearest = krisis.suggest key known;
                in
                lib.optional (nearest != null) "did you mean '${nearest}'?";
            };
          }) strayKeys;

          # a target two things want is reported once, against the later of
          # the two
          claimantOf =
            key:
            let
              target = renames.${key};
              position = lib.lists.findFirstIndex (candidate: candidate == key) 0 validKeys;
              earlier = builtins.filter (other: renames.${other} == target) (lib.take position validKeys);
            in
            if earlier != [ ] then
              "the rename of ${builtins.head earlier}"
            else if builtins.elem target staying then
              "the ${rootKind} ${target} of this source"
            else if builtins.elem target (declaredNames rootKind) then
              "the declared ${rootKind} ${target}"
            else
              null;

          collisionProblems = lib.concatMap (
            key:
            let
              claimant = claimantOf key;
            in
            lib.optional (claimant != null) {
              code = "rename-collision";
              args = {
                at = entry.at ++ [
                  "renames"
                  key
                ];
                context = {
                  rename = key;
                  name = renames.${key};
                  inherit claimant;
                };
              };
            }
          ) validKeys;

          # a rename moves a host off the name it would have paired with, so
          # the pairing that changed is said out loud
          repairing = lib.concatMap (
            key:
            let
              entity = rootAt key;
              target = renames.${key};
            in
            lib.optional (builtins.elem entity.name (declaredNames rootKind) && target != entity.name) {
              code = "rename-repairing";
              args = {
                at = entry.at ++ [
                  "renames"
                  key
                ];
                context = {
                  host = sourceKeyOf entity;
                  name = target;
                };
              };
            }
          ) validKeys;

          rootEntities = map (entity: {
            inherit (entity) kind;
            name = finalOf entity;
            key = finalOf entity;
            parentKey = null;
            source = label;
            sourcePath = entry.at ++ entity.path;
            system = systemOf entity;
            evidence = if entity.evidence == null then sourceKeyOf entity else entity.evidence;
            inherit (entity) fields inherited;
          }) roots;

          ownerOf =
            child:
            lib.findFirst (root: lib.take (builtins.length root.path) child.path == root.path) null roots;

          childEntities = map (
            child:
            let
              owner = ownerOf child;
            in
            {
              inherit (child) kind name;
              key = "${finalOf owner}.${child.name}";
              parentKey = finalOf owner;
              source = label;
              sourcePath = entry.at ++ child.path;
              system = systemOf child;
              inherit (child) fields inherited;
            }
          ) children;

          # narrowing is a reading of its own. a source addresses entities
          # by more than a name and this registry addresses them by one
          claiming = name: builtins.filter (entity: entity.key == name) rootEntities;

          narrowed = builtins.filter (name: builtins.length (claiming name) > 1) (
            lib.unique (map (entity: entity.key) rootEntities)
          );

          # one name, one diagnostic, and everything that narrowed onto it
          # is locatable. the source's own display string is the evidence
          narrowingProblems = map (
            name:
            let
              group = claiming name;
            in
            {
              code = "narrowing-collision";
              args = {
                at = (builtins.head group).sourcePath;
                notes = map (entity: krisis.renderPath entity.sourcePath) (builtins.tail group);
                context = {
                  inherit name;
                  systems = lib.concatStringsSep ", " (map (entity: entity.system) group);
                  evidence = lib.concatStringsSep ", " (map (entity: entity.evidence) group);
                };
              };
            }
          ) narrowed;

          # the first claimant keeps the name
          losing = lib.concatMap (name: builtins.tail (claiming name)) narrowed;

          lost = entity: builtins.any (other: other.sourcePath == entity.sourcePath) losing;

          under = root: child: lib.take (builtins.length root.sourcePath) child.sourcePath == root.sourcePath;

          kept =
            builtins.filter (entity: !lost entity) rootEntities
            ++ builtins.filter (child: !(builtins.any (root: under root child) losing)) childEntities;
        in
        {
          inherit (entry) at;
          inherit label usable;
          problems =
            shapeProblems
            ++ unknownProblems
            ++ collisionProblems
            ++ repairing
            ++ lib.optionals usable narrowingProblems;
          entities = if usable then kept else [ ];
        };

      readings = map readEntry (entriesOf written);

      named = builtins.filter (reading: reading.usable) readings;

      # the name keys inherited, so two sources of one name would write into
      # one slot. the second of a name is reported where it is written
      nameProblems = lib.concatMap (
        index:
        let
          reading = builtins.elemAt named index;
          earlier = builtins.filter (other: other.label == reading.label) (lib.take index named);
        in
        lib.optional (earlier != [ ]) {
          code = "source-name-collision";
          args = {
            inherit (reading) at;
            notes = [ (krisis.renderPath (builtins.head earlier).at) ];
            context = {
              name = reading.label;
            };
          };
        }
      ) (lib.range 0 (builtins.length named - 1));

      # anything but a list at the key is reported once and read no further
      keyProblems = lib.optional (written != null && !builtins.isList written) (
        invalidValue [
          "sources"
        ] "sources" "a list of sources built with lexicon.source.den" (builtins.typeOf written) [ takes ]
      );
    in
    {
      entities = lib.concatMap (reading: reading.entities) readings;
      problems = keyProblems ++ lib.concatMap (reading: reading.problems) readings ++ nameProblems;
    };
in
{
  inherit
    read
    adapters
    den
    ;
}
