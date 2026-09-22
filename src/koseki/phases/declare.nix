# phase one reshapes and nothing else. no defaults, no derivations, no type
# checks, and no opinion about what any field means
{
  lib,
  krisis,
  sources,
  retired,
}:
let
  sourceKeys = [
    "sources"
  ];

  run =
    { kinds }:
    declaration:
    let
      roots = builtins.filter (kind: kind.parent == null) kinds;
      childrenOf = name: builtins.filter (kind: kind.parent == name) kinds;
      kindNamed = name: lib.findFirst (kind: kind.name == name) null kinds;

      collections = map (kind: kind.collection) roots;
      recognised = collections ++ sourceKeys;

      keys = if builtins.isAttrs declaration then builtins.attrNames declaration else [ ];
      unknown = builtins.filter (key: !builtins.elem key recognised) keys;

      walk =
        kind: parent: base: attrs:
        lib.concatLists (
          lib.mapAttrsToList (
            name: raw:
            let
              sourcePath = base ++ [ name ];
              entry = {
                kind = kind.name;
                inherit
                  name
                  raw
                  sourcePath
                  parent
                  ;
              };
              nested = lib.concatMap (
                child:
                let
                  held = raw.${child.container} or null;
                in
                if builtins.isAttrs held then walk child entry (sourcePath ++ [ child.container ]) held else [ ]
              ) (childrenOf kind.name);
            in
            [ entry ] ++ nested
          ) (if builtins.isAttrs attrs then attrs else { })
        );

      declared = lib.concatMap (
        kind:
        let
          held = declaration.${kind.collection} or null;
        in
        if builtins.isAttrs held then walk kind null [ kind.collection ] held else [ ]
      ) roots;

      read = sources.read { inherit kinds declaration; };

      keyOf = entry: if entry.parent == null then entry.name else "${keyOf entry.parent}.${entry.name}";

      identityOf = kind: key: "${kind}.${key}";

      # a declaration entity and a source entity of one identity are one
      # entity, and the declaration is read last so the author writes last
      declaredIdentities = map (entry: {
        identity = identityOf entry.kind (keyOf entry);
        inherit entry;
      }) declared;

      contributed = map (entity: {
        identity = identityOf entity.kind entity.key;
        inherit entity;
      }) read.entities;

      identities = lib.unique (map (held: held.identity) (declaredIdentities ++ contributed));

      declaredAt = identity: lib.findFirst (held: held.identity == identity) null declaredIdentities;

      contributedAt =
        identity: map (held: held.entity) (builtins.filter (held: held.identity == identity) contributed);

      # a child says which entity it belongs to, whoever wrote it, so the
      # containers of an entity are known before any of them is read
      childLinks =
        map (held: {
          parent = identityOf held.entry.parent.kind (keyOf held.entry.parent);
          inherit (held) identity;
        }) (builtins.filter (held: held.entry.parent != null) declaredIdentities)
        ++ map (held: {
          parent = identityOf (kindNamed held.entity.kind).parent held.entity.parentKey;
          inherit (held) identity;
        }) (builtins.filter (held: held.entity.parentKey != null) contributed);

      childrenUnder =
        identity:
        lib.unique (map (link: link.identity) (builtins.filter (link: link.parent == identity) childLinks));

      entryFor =
        identity:
        let
          held = declaredAt identity;
          hits = contributedAt identity;
          base = if held == null then null else held.entry;
          first = if hits == [ ] then null else builtins.head hits;
          kind = if base != null then base.kind else first.kind;
          described = kindNamed kind;

          parent =
            if base != null then
              (
                if base.parent == null then null else byIdentity.${identityOf base.parent.kind (keyOf base.parent)}
              )
            else if described.parent == null then
              null
            else
              byIdentity.${identityOf described.parent first.parentKey} or null;

          written =
            map (hit: {
              inherit (hit) source sourcePath fields;
            }) hits
            ++ lib.optional (base != null) {
              source = "declaration";
              inherit (base) sourcePath;
              fields = if builtins.isAttrs base.raw then base.raw else { };
            };

          folded = lib.foldl' (accumulated: contribution: accumulated // contribution.fields) { } written;

          children = childrenOf kind;

          containerKeys = map (child: child.container) children;

          childrenOfKind =
            child: builtins.filter (id: byIdentity.${id}.kind == child.name) (childrenUnder identity);

          # a container names the child entities of this entity, so the
          # field and the registry say the same thing
          containerFields = lib.listToAttrs (
            lib.concatMap (
              child:
              let
                under = childrenOfKind child;
                value = folded.${child.container} or null;
              in
              lib.optional (under != [ ] || base == null || folded ? ${child.container}) (
                lib.nameValuePair child.container (
                  if under == [ ] && value != null && !builtins.isAttrs value then
                    value
                  else
                    lib.listToAttrs (map (id: lib.nameValuePair byIdentity.${id}.name byIdentity.${id}.raw) under)
                )
              )
            ) children
          );

          home =
            if base != null then
              {
                source = "declaration";
                inherit (base) sourcePath;
              }
            else
              { inherit (first) source sourcePath; };

          contributions =
            map (
              contribution:
              contribution
              // {
                fields = builtins.removeAttrs contribution.fields containerKeys;
              }
            ) written
            ++ lib.optional (containerFields != { }) (home // { fields = containerFields; });
        in
        {
          inherit kind parent contributions;
          name = if base != null then base.name else first.name;
          sourcePath = if base != null then base.sourcePath else first.sourcePath;

          # what the entity was written as, in fold order, so a later writer
          # is what the next phase resolves against
          raw = lib.foldl' (accumulated: contribution: accumulated // contribution.fields) { } contributions;

          # reachable from no query. a source's own spelling of a field is
          # kept whole and merged into nothing
          inherited = lib.listToAttrs (map (hit: lib.nameValuePair hit.source hit.inherited) hits);
        };

      byIdentity = lib.listToAttrs (
        map (identity: lib.nameValuePair identity (entryFor identity)) identities
      );

      entries = map (identity: byIdentity.${identity}) identities;

      # a top-level key no kind claims. nothing after this phase looks at it
      # again, so it is reported here and dropped
      unknownProblems = map (key: {
        code = "unknown-kind";
        args = {
          at = [ key ];
          context = {
            inherit key;
          };
          notes =
            let
              nearest = krisis.suggest key recognised;
            in
            lib.optional (nearest != null) "did you mean '${nearest}'?" ++ retired.noteFor key;
        };
      }) unknown;
    in
    {
      inherit entries;
      problems = unknownProblems ++ read.problems;
    };
in
{
  inherit run;
}
