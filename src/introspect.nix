# the read-only view. it answers what a caller may write, what the walk read
# and what the registry made of it, off the same registries the run reads.
# nothing here opens a run, so nothing here reports
{
  lib,
  fx,
  t,
  arrows,
  kinds,
  blocks,
  construct,
  claimKeys,
  version,
}:
let
  FieldName = t.refined "FieldName" t.String (value: value != "");

  Provenance = arrows.sum {
    written = t.Attrs;
    filled = FieldName;
  };

  Kind = t.bless (
    fx.types.Record {
      name = t.String;
      collection = t.String;
      declare = t.Bool;
      within = t.nullOr t.String;
      blocks = t.listOf t.String;
    }
  );

  Block = t.bless (
    fx.types.Record {
      name = t.String;
      kinds = t.listOf t.String;
      before = t.listOf t.String;
      claimable = t.Bool;
      routes = t.listOf (t.listOf t.String);
    }
  );

  File = t.bless (
    fx.types.Record {
      name = t.String;
      kind = t.String;
      origin = t.nullOr t.String;
      blocks = t.listOf t.String;
      unregistered = t.listOf t.String;
      includes = t.listOf (t.nullOr t.String);
    }
  );

  Entity = t.bless (
    fx.types.Record {
      kind = t.String;
      name = t.String;
      fields = t.Attrs;
      children = t.Attrs;
      claimed = t.Attrs;
    }
  );

  Origin = t.bless (
    fx.types.Record {
      kind = t.String;
      name = t.String;
      field = FieldName;
      provenance = t.Attrs;
    }
  );

  Introspection = t.bless (
    fx.types.Record {
      kinds = t.listOf Kind;
      blocks = t.listOf Block;
      files = t.listOf File;
      fleet = t.listOf Entity;
      origins = t.listOf Origin;
      lines = t.listOf t.String;
    }
  );

  sorted = names: lib.sort (a: b: a < b) names;

  rooted = builtins.filter (kind: kind.parent == null) kinds;

  childrenIn = kind: builtins.filter (one: one.parent == kind.name) kinds;

  # the kinds that carry blocks are the ones a claim narrows the reach of
  carriers = builtins.filter (kind: !kind.declare) kinds;

  sortedBlocks =
    names:
    lib.foldl'
      (
        gathered: name:
        blocks.Registration.case {
          known = held: gathered // { known = gathered.known ++ [ held ]; };
          unregistered = held: gathered // { unregistered = gathered.unregistered ++ [ held ]; };
        } (blocks.classify name)
      )
      {
        known = [ ];
        unregistered = [ ];
      }
      names;

  kindsOf = map (kind: {
    inherit (kind) name collection declare;
    within = kind.parent;
    blocks = blocks.allowedIn kind.name;
  }) kinds;

  blocksOf = map (
    name:
    let
      held = blocks.byName.${name};
    in
    {
      inherit (held) name kinds before;
      claimable = held.claimable != [ ];
      routes = held.claimable;
    }
  ) blocks.order;

  filesOf =
    walked:
    map (
      name:
      let
        payload = construct.read walked.${name};
        held = sortedBlocks (sorted (builtins.attrNames payload.blocks));
      in
      {
        inherit name;
        inherit (payload) kind origin;
        blocks = held.known;
        inherit (held) unregistered;
        includes = map (one: (construct.read one).origin) (
          builtins.filter construct.isSound payload.includes
        );
      }
    ) (sorted (builtins.filter (name: construct.isSound walked.${name}) (builtins.attrNames walked)));

  fieldsOf = entity: builtins.removeAttrs entity [ "name" ];

  childrenOf =
    registry: kind: entity:
    lib.listToAttrs (
      map (
        child:
        lib.nameValuePair child.collection (map (one: one.name) (registry."${child.collection}Of" entity))
      ) (childrenIn kind)
    );

  # a facet reaches an entity when the claim on the block it carries names
  # that entity or names nobody
  reaches =
    key: entity: claim:
    (claim.${key} or [ ]) == [ ] || builtins.elem entity.name claim.${key};

  carriedBy =
    registry: claims: key: entity: carrier:
    lib.listToAttrs (
      lib.concatMap (
        held:
        let
          kept = builtins.filter (
            block: reaches key entity (claims.${held.name}.${block} or { })
          ) (sortedBlocks (sorted (builtins.attrNames held.blocks))).known;
        in
        lib.optional (kept != [ ]) (lib.nameValuePair held.name kept)
      ) registry.${carrier.collection}
    );

  claimsOn =
    registry: claims: kind: entity:
    lib.optionalAttrs (builtins.elem kind.collection claimKeys) (
      lib.listToAttrs (
        map (
          carrier:
          lib.nameValuePair carrier.collection (carriedBy registry claims kind.collection entity carrier)
        ) carriers
      )
    );

  # the descent is the one the kind registry declares, so a kind nested under
  # another is reached without this file knowing either name
  entitiesUnder =
    registry: kind: parent: entity:
    [
      {
        inherit kind entity parent;
      }
    ]
    ++ lib.concatMap (
      child:
      lib.concatMap (one: entitiesUnder registry child entity.name one) (
        registry."${child.collection}Of" entity
      )
    ) (childrenIn kind);

  entitiesOf =
    registry:
    lib.concatMap (
      kind: lib.concatMap (entitiesUnder registry kind null) registry.${kind.collection}
    ) rooted;

  fleetOf =
    prepared:
    map (held: {
      kind = held.kind.name;
      inherit (held.entity) name;
      fields = fieldsOf held.entity;
      children = childrenOf prepared.registry held.kind held.entity;
      claimed = claimsOn prepared.registry prepared.claims held.kind held.entity;
    }) (entitiesOf prepared.registry);

  # a lookup takes whatever its kind's key is built from, and the key of a
  # nested kind is the pair
  argumentFor =
    kind: parent: name:
    if kind.parent == null then
      name
    else
      {
        ${kind.parent} = parent;
        inherit name;
      };

  provenanceOf =
    registry: held: field:
    let
      found = registry.originOf {
        kind = held.kind.name;
        name = argumentFor held.kind held.parent held.entity.name;
        inherit field;
      };
    in
    if found == null then Provenance.inject.filled field else Provenance.inject.written found;

  originsOf =
    registry:
    lib.concatMap (
      held:
      map (field: {
        kind = held.kind.name;
        inherit (held.entity) name;
        inherit field;
        provenance = provenanceOf registry held field;
      }) (sorted (builtins.attrNames (fieldsOf held.entity)))
    ) (entitiesOf registry);

  # an interior is a value the module system will read and may well be a
  # function, so a set is shown by the names it holds
  shown =
    value:
    if builtins.isString value then
      value
    else if builtins.isList value then
      lib.concatMapStringsSep " " shown value
    else if builtins.isAttrs value then
      shown (sorted (builtins.attrNames value))
    else if builtins.isFunction value then
      "a function"
    else
      builtins.toJSON value;

  listed =
    value:
    let
      text = shown value;
    in
    if text == "" then "none" else text;

  joined = parts: "  " + builtins.concatStringsSep "  " parts;

  nested = parts: "    " + builtins.concatStringsSep "  " parts;

  kindLine =
    kind:
    joined (
      [
        kind.name
        kind.collection
      ]
      ++ lib.optional kind.declare "declare"
      ++ lib.optional (kind.within != null) "inside ${kind.within}"
      ++ lib.optional (kind.blocks != [ ]) "blocks ${shown kind.blocks}"
    );

  blockLine =
    block:
    joined (
      [
        block.name
        (shown block.kinds)
      ]
      ++ lib.optional (block.before != [ ]) "before ${shown block.before}"
      ++ lib.optional block.claimable "claimable ${toString (builtins.length block.routes)} routes"
    );

  fileLine =
    file:
    joined (
      [
        file.name
        file.kind
        (shown file.origin)
      ]
      ++ lib.optional (file.blocks != [ ]) "blocks ${shown file.blocks}"
      ++ lib.optional (file.unregistered != [ ]) "unregistered ${shown file.unregistered}"
      ++ lib.optional (file.includes != [ ]) "includes ${shown file.includes}"
    );

  entityLines =
    entity:
    [ "${entity.kind} ${entity.name}" ]
    ++ map (
      field:
      joined [
        field
        (listed entity.fields.${field})
      ]
    ) (sorted (builtins.attrNames entity.fields))
    ++ lib.mapAttrsToList (
      collection: names:
      nested [
        collection
        (listed names)
      ]
    ) entity.children
    ++ lib.mapAttrsToList (
      collection: held:
      nested [
        collection
        (listed (sorted (builtins.attrNames held)))
      ]
    ) entity.claimed;

  weighed = Provenance.case {
    written = _: 1;
    filled = _: 0;
  };

  linesOf =
    answer:
    let
      written = lib.foldl' (total: one: total + weighed one.provenance) 0 answer.origins;

      header = builtins.concatStringsSep ", " [
        "lexicon ${version}"
        "${toString (builtins.length answer.kinds)} kinds"
        "${toString (builtins.length answer.blocks)} blocks"
        "${toString (builtins.length answer.files)} declarations"
      ];
    in
    [
      header
      "kinds"
    ]
    ++ map kindLine answer.kinds
    ++ [ "blocks" ]
    ++ map blockLine answer.blocks
    ++ [ "files" ]
    ++ map fileLine answer.files
    ++ lib.concatMap entityLines answer.fleet
    ++ [
      "fields written by hand ${toString written}"
      "fields filled by lexicon ${toString (builtins.length answer.origins - written)}"
    ];

  introspect =
    { walked, prepared }:
    let
      answered = {
        kinds = kindsOf;
        blocks = blocksOf;
        files = filesOf walked;
        fleet = fleetOf prepared;
        origins = originsOf prepared.registry;
      };
    in
    answered // { lines = linesOf answered; };
in
{
  inherit introspect;

  types = {
    inherit
      Kind
      Block
      File
      Entity
      Origin
      Provenance
      Introspection
      ;
  };
}
