# the accessors close over the registry. nothing they hand back reaches it,
# and every name below is built from the kind descriptions rather than
# written out
{
  lib,
  fx,
  vocabulary,
  accessors,
}:
let
  inherit (vocabulary) emit;

  make =
    {
      kinds,
      provenance,
      entities,
    }:
    let
      ofKind = name: builtins.filter (entity: entity.kind == name) entities;

      find =
        name: key: lib.findFirst (entity: entity.kind == name && entity.key == key) null (ofKind name);

      # plain author-facing data, nothing else like at all
      plain = entity: if entity == null then null else entity.value;

      keyFor =
        kind: argument:
        if kind.parent == null then
          toString argument
        else
          "${toString argument.${kind.parent}}.${toString argument.name}";

      lookup = kind: argument: plain (find kind.name (keyFor kind argument));

      childrenOf =
        kind: owner:
        map plain (builtins.filter (entity: lib.hasPrefix "${owner.name}." entity.key) (ofKind kind.name));

      collectionLayer = lib.listToAttrs (
        map (kind: lib.nameValuePair kind.collection (map plain (ofKind kind.name))) kinds
      );

      lookupLayer = lib.listToAttrs (
        map (kind: lib.nameValuePair kind.name (argument: lookup kind argument)) kinds
      );

      childLayer = lib.listToAttrs (
        map (kind: lib.nameValuePair "${kind.collection}Of" (childrenOf kind)) (
          builtins.filter (kind: kind.parent != null) kinds
        )
      );

      # one accessor per field name, over the union across the resolved kinds.
      # the body reads the field off whatever entity it is handed
      fieldLayer = lib.listToAttrs (
        map (name: lib.nameValuePair "${name}Of" (entity: entity.${name} or null)) (
          accessors.fieldNames kinds
        )
      );

      # precedence comes from the layer list and nothing else. the order the
      # kinds resolved in must never decide which accessor a caller gets
      namespace = accessors.merge {
        collection = collectionLayer;
        lookup = lookupLayer;
        child = childLayer;
        field = fieldLayer;
      };

      requireFor =
        kind:
        lib.nameValuePair kind.name (
          argument:
          let
            found = lookup kind argument;
          in
          if found != null then
            fx.pure found
          else
            fx.bind (emit."unknown-${kind.name}" {
              context = {
                name = keyFor kind argument;
              };
            }) (_: fx.pure null)
        );

      kindNamed = name: lib.findFirst (kind: kind.name == name) null kinds;

      queries = namespace // {
        require = lib.listToAttrs (map requireFor kinds);

        # name is whatever the kind's own lookup takes, so keyFor stays the
        # one place a key is built. derived values have no origin and say so
        originOf =
          {
            kind,
            name,
            field,
          }:
          let
            described = kindNamed kind;
            found = if described == null then null else find kind (keyFor described name);
          in
          if found == null then null else provenance."${found.path}.${field}" or null;
      };

      # diagnostics are the run's, not the registry's; the door attaches them
      # once the policy has finished with them
      withDiagnostics =
        diagnostics:
        queries
        // {
          diagnosticsByPath = lib.foldl' (
            accumulated: diagnostic:
            let
              at = if diagnostic.at == null then "" else diagnostic.at;
            in
            accumulated // { ${at} = (accumulated.${at} or [ ]) ++ [ diagnostic ]; }
          ) { } diagnostics;
        };
    in
    queries // { inherit withDiagnostics; };
in
{
  inherit make;
}
