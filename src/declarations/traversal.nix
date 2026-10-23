{
  lib,
  axiom,
  krisis,
  environment,
}:
let
  report = import ./report.nix { inherit lib axiom krisis; };
  inherit (report) at schema;
  inherit (axiom) validation;
  inherit (environment)
    descriptorSet
    ownerships
    metadataFields
    annotationNames
    ;
  axes = import ../ownerships/axes.nix { inherit lib axiom krisis; };
  claimAttrs = lib.genAttrs descriptorSet.claimKeys (_: null);
  claimsOf = builtins.intersectAttrs claimAttrs;
  claimErrors =
    path: value:
    builtins.concatMap (
      key:
      lib.optional (value ? ${key.name} && !key.valid value.${key.name}) (
        at (path ++ [ key.name ]) "annotation-shape" (key.shapeError value.${key.name})
      )
    ) descriptorSet.authorKeys;
  strip = value: removeAttrs value annotationNames;
  unit =
    path: chain:
    lib.foldr (claims: child: claims // { children = [ child ]; }) {
      lexiconSelected = true;
      label = krisis.renderPath path;
    } chain;
  collect = results: validation.map (_: true) (validation.sequence results);
  childArgs = args: args // { project = false; };
  directErrors =
    path: claims:
    map (
      name: at (path ++ [ name ]) "direct-annotation" "direct binding rejects ownership annotations"
    ) (builtins.attrNames claims);
  inactive = {
    selected = false;
  };
  bundle = values: {
    value = map (value: value.value) values;
    metadata = map (value: value.metadata) values;
    origins = map (value: value.origins) values;
    prepared = map (value: value.prepared) values;
  };

  prepare =
    node: path: raw:
    if node.kind == "reference" then
      prepare node.target path raw
    else if node.kind == "projection" then
      let
        child = prepare node.item path raw;
      in
      child
      // {
        bindSelection =
          args: context:
          if
            builtins.any (
              name:
              builtins.elem name (
                args.outputs or [
                  "nixos"
                  "homeManager"
                  "resources"
                ]
              )
            ) node.outputs
          then
            child.bindSelection args context
          else
            validation.success inactive;
      }
    else if node.kind == "contextual" then
      if !builtins.isFunction raw then
        prepare node.item path raw
      else
        {
          structural = validation.success true;
          claimPaths = [ ];
          origins = path;
          structure = raw;
          scopeResult = _: validation.success true;
          bindSelection =
            args: context:
            krisis.withErrorContext "lexicon callback at ${krisis.renderPath path}" (
              let
                result = raw (removeAttrs context [ "mergeSystem" ]);
                shape = validation.fromDiagnostics (lib.optional (builtins.isFunction result) (
                  at path "callback-result" "context callback must return data, not another function"
                )) result;
              in
              validation.andThen (
                value:
                let
                  child = prepare node.item path value;
                  direct = validation.fromDiagnostics (lib.optionals args.direct (
                    map (
                      claim: at claim "direct-annotation" "direct binding rejects ownership annotations"
                    ) child.claimPaths
                  )) true;
                in
                validation.andThen (_: child.bindSelection args context) (
                  validation.andThen (_: child.scopeResult args) (validation.andThen (_: direct) child.structural)
                )
              ) shape
            );
        }
    else
      let
        record =
          let
            shape =
              (schema path (
                lib.genAttrs (
                  builtins.attrNames node.fields ++ builtins.attrNames node.children ++ annotationNames
                ) (_: { })
              ))
                raw;
            ownShape = validation.andThen (
              value:
              validation.fromDiagnostics (
                claimErrors path value
                ++ lib.optional (value ? metadata && !builtins.isAttrs value.metadata) (
                  at (path ++ [ "metadata" ]) "metadata-shape" "metadata must be a record"
                )
              ) value
            ) shape;
            structure = ownShape.value;
            children = lib.mapAttrs (name: child: prepare child (path ++ [ name ]) structure.${name}) (
              lib.filterAttrs (name: _: structure ? ${name}) node.children
            );
            childNames = builtins.attrNames children;
            ownClaims = claimsOf structure;
            structural = validation.andThen (
              _: validation.map (_: true) (validation.traverseAttrs (_: child: child.structural) children)
            ) ownShape;
            origins = {
              self = path;
              children = lib.mapAttrs (_: child: child.origins) children;
            };
            # this thunk belongs to the authored occurrence, outside context-dependent selection
            ownPrepared = krisis.withErrorContext "lexicon preparation at ${krisis.renderPath path}" (
              node.prepare { inherit structure origins; }
            );
            domain = removeAttrs (strip structure) childNames;
          in
          {
            inherit
              structural
              origins
              children
              structure
              ;
            claimPaths =
              map (name: path ++ [ name ]) (builtins.attrNames ownClaims)
              ++ builtins.concatMap (name: children.${name}.claimPaths) childNames;
            scopeResult =
              args:
              validation.andThen (
                _:
                collect (
                  [
                    (validation.fromDiagnostics (
                      if args.project or false then
                        [ ]
                      else
                        builtins.concatMap (
                          key:
                          lib.optional (ownClaims ? ${key.name}) (
                            at (path ++ [ key.name ]) "annotation-scope" (
                              key.scopeError args.scope key.name ownClaims.${key.name}
                            )
                          )
                        ) (axes.forbiddenKeysFor environment.descriptors args.scope)
                    ) true)
                  ]
                  ++ map (name: children.${name}.scopeResult (childArgs args)) childNames
                )
              ) structural;
            bindSelection =
              args:
              let
                claims = if args.project or false then ownerships.projectClaims args.scope ownClaims else ownClaims;
                chain = args.ancestors ++ [ claims ];
                selectedFor =
                  if args.direct then _: { lexiconSelected = true; } else args.resolve [ (unit path chain) ];
                childBindings = lib.mapAttrs (
                  _: child: child.bindSelection (childArgs args // { ancestors = chain; })
                ) children;
              in
              context:
              validation.andThen (
                _:
                if !(selectedFor context).lexiconSelected or false then
                  validation.success inactive
                else
                  let
                    ownPayload =
                      validation.map2 (value: metadata: { inherit value metadata; }) ((schema path node.fields) domain)
                        ((schema (path ++ [ "metadata" ]) metadataFields) (structure.metadata or { }));
                    selectedChildren = validation.traverseAttrs (_: select: select context) childBindings;
                  in
                  validation.map2 (
                    payload: childValues:
                    let
                      active = lib.filterAttrs (_: child: child.selected) childValues;
                    in
                    {
                      selected = true;
                      value = payload.value // lib.mapAttrs (_: child: child.value) active;
                      metadata = {
                        self = payload.metadata;
                        children = lib.mapAttrs (_: child: child.metadata) active;
                      };
                      origins = {
                        self = path;
                        children = lib.mapAttrs (_: child: child.origins) active;
                      };
                      prepared = {
                        self = ownPrepared;
                        children = lib.mapAttrs (_: child: child.prepared) active;
                      };
                    }
                  ) ownPayload selectedChildren
              ) (validation.fromDiagnostics (lib.optionals args.direct (directErrors path ownClaims)) true);
          };
        collection =
          let
            shape = validation.fromDiagnostics (lib.optional (!builtins.isList raw) (
              at path "collection-shape" "expected a list"
            )) raw;
            items = lib.imap0 (index: value: prepare node.item (path ++ [ index ]) value) shape.value;
            structural = validation.andThen (_: collect (map (item: item.structural) items)) shape;
          in
          {
            inherit structural;
            claimPaths = builtins.concatMap (item: item.claimPaths) items;
            origins = map (item: item.origins) items;
            structure = raw;
            scopeResult =
              args:
              validation.andThen (_: collect (map (item: item.scopeResult (childArgs args)) items)) structural;
            bindSelection =
              args:
              let
                bindings = map (item: item.bindSelection (childArgs args)) items;
              in
              context:
              validation.map (
                values: { selected = true; } // bundle (builtins.filter (value: value.selected) values)
              ) (validation.sequence (map (select: select context) bindings));
          };
        recordMap =
          let
            shape = validation.fromDiagnostics (lib.optional (!builtins.isAttrs raw) (
              at path "record-map-shape" "expected a record map"
            )) raw;
            keyed = validation.andThen (
              value:
              validation.fromDiagnostics (map (
                name: at (path ++ [ name ]) "record-map-key" "invalid record map key"
              ) (builtins.filter (name: !node.key name) (builtins.attrNames value))) value
            ) shape;
            items = lib.mapAttrs (name: prepare node.item (path ++ [ name ])) keyed.value;
            structural = validation.andThen (
              _: validation.map (_: true) (validation.traverseAttrs (_: item: item.structural) items)
            ) keyed;
          in
          {
            inherit structural;
            claimPaths = builtins.concatMap (name: items.${name}.claimPaths) (builtins.attrNames items);
            origins = lib.mapAttrs (_: item: item.origins) items;
            structure = raw;
            scopeResult =
              args:
              validation.andThen (
                _: collect (map (name: items.${name}.scopeResult (childArgs args)) (builtins.attrNames items))
              ) structural;
            bindSelection =
              args:
              let
                bindings = lib.mapAttrs (_: item: item.bindSelection (childArgs args)) items;
              in
              context:
              validation.map (
                values:
                let
                  selected = lib.filterAttrs (_: item: item.selected) values;
                in
                {
                  selected = true;
                  value = lib.mapAttrs (_: item: item.value) selected;
                  metadata = lib.mapAttrs (_: item: item.metadata) selected;
                  origins = lib.mapAttrs (_: item: item.origins) selected;
                  prepared = lib.mapAttrs (_: item: item.prepared) selected;
                }
              ) (validation.traverseAttrs (_: select: select context) bindings);
          };
        leaf = {
          structural = validation.success true;
          claimPaths = [ ];
          origins = path;
          structure = raw;
          scopeResult = _: validation.success true;
          bindSelection =
            _: _:
            let
              payload =
                if node.kind == "native" then
                  validation.fromDiagnostics (lib.optional (!node.validate raw) (
                    at path "native-shape" "invalid ${node.owner} payload"
                  )) raw
                else
                  validation.mapDiagnostics (
                    diagnostic:
                    diagnostic
                    // {
                      primary = (diagnostic.primary or { }) // {
                        label = krisis.renderPath path;
                      };
                    }
                  ) (validation.map (result: result.value) ((schema path { value = node.field; }) { value = raw; }));
            in
            validation.map (value: {
              selected = true;
              inherit value;
              metadata = { };
              origins = path;
              prepared = { };
            }) payload;
        };
      in
      {
        inherit record;
        inherit collection;
        "record-map" = recordMap;
        value = leaf;
        native = leaf;
      }
      .${node.kind};
in
{
  inherit prepare claimsOf;
}
