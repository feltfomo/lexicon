{
  lib,
  axiom,
  krisis,
  environment,
}:
let
  report = import ./report.nix { inherit lib axiom krisis; };
  inherit (report) at schema;
  inherit (krisis.effects)
    native
    accept
    fromAxiom
    fromDiagnostics
    ;
  inherit (native) validation;
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
  collect = checks: validation.andThen (_: accept true) (validation.all checks);
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
  named =
    names: values:
    builtins.listToAttrs (
      lib.imap0 (index: name: {
        inherit name;
        value = builtins.elemAt values index;
      }) names
    );
  recordEntry =
    node: path: structure: children:
    let
      childNames = builtins.attrNames children;
      ownClaims = claimsOf structure;
      origins = {
        self = path;
        children = lib.mapAttrs (_: child: child.origins) children;
      };
      # preparation belongs to the validated authored occurrence, before context binding
      ownPrepared = krisis.withErrorContext "lexicon preparation at ${krisis.renderPath path}" (
        node.prepare { inherit structure origins; }
      );
      domain = removeAttrs (strip structure) childNames;
    in
    {
      inherit structure origins children;
      claimPaths =
        map (name: path ++ [ name ]) (builtins.attrNames ownClaims)
        ++ builtins.concatMap (name: children.${name}.claimPaths) childNames;
      scopeResult =
        args:
        collect (
          [
            (fromDiagnostics (
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
        );
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
            accept inactive
          else
            validation.andThen
              (
                results:
                let
                  childValues = named childNames (lib.drop 2 results);
                  active = lib.filterAttrs (_: child: child.selected) childValues;
                in
                accept {
                  selected = true;
                  value = builtins.elemAt results 0 // lib.mapAttrs (_: child: child.value) active;
                  metadata = {
                    self = builtins.elemAt results 1;
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
              )
              (
                validation.all (
                  [
                    (fromAxiom ((schema path node.fields) domain))
                    (fromAxiom ((schema (path ++ [ "metadata" ]) metadataFields) (structure.metadata or { })))
                  ]
                  ++ map (name: childBindings.${name} context) childNames
                )
              )
        ) (fromDiagnostics (lib.optionals args.direct (directErrors path ownClaims)) true);
    };
  prepare =
    node: path: raw:
    if node.kind == "reference" then
      prepare node.target path raw
    else if node.kind == "projection" then
      validation.andThen (
        child:
        accept (
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
                accept inactive;
          }
        )
      ) (prepare node.item path raw)
    else if node.kind == "contextual" then
      if !builtins.isFunction raw then
        prepare node.item path raw
      else
        accept {
          claimPaths = [ ];
          origins = path;
          structure = raw;
          scopeResult = _: accept true;
          bindSelection =
            args: context:
            let
              result = krisis.withErrorContext "lexicon callback at ${krisis.renderPath path}" (
                raw (removeAttrs context [ "mergeSystem" ])
              );
              shape = fromDiagnostics (lib.optional (builtins.isFunction result) (
                at path "callback-result" "context callback must return data, not another function"
              )) result;
            in
            validation.andThen (
              value:
              validation.andThen (
                child:
                validation.andThen (_: child.bindSelection args context) (
                  validation.andThen (_: child.scopeResult args) (
                    fromDiagnostics (lib.optionals args.direct (
                      map (
                        claim: at claim "direct-annotation" "direct binding rejects ownership annotations"
                      ) child.claimPaths
                    )) true
                  )
                )
              ) (prepare node.item path value)
            ) shape;
        }
    else
      let
        cases = {
          record =
            validation.andThen
              (
                structure:
                validation.andThen
                  (
                    _:
                    let
                      present = lib.filterAttrs (name: _: structure ? ${name}) node.children;
                      names = builtins.attrNames present;
                    in
                    validation.andThen (values: accept (recordEntry node path structure (named names values))) (
                      validation.all (map (name: prepare present.${name} (path ++ [ name ]) structure.${name}) names)
                    )
                  )
                  (
                    fromDiagnostics (
                      claimErrors path structure
                      ++ lib.optional (structure ? metadata && !builtins.isAttrs structure.metadata) (
                        at (path ++ [ "metadata" ]) "metadata-shape" "metadata must be a record"
                      )
                    ) true
                  )
              )
              (
                fromAxiom (
                  (schema path (
                    lib.genAttrs (
                      builtins.attrNames node.fields ++ builtins.attrNames node.children ++ annotationNames
                    ) (_: { })
                  ))
                    raw
                )
              );
          collection =
            validation.andThen
              (
                _:
                validation.andThen (
                  items:
                  accept {
                    claimPaths = builtins.concatMap (item: item.claimPaths) items;
                    origins = map (item: item.origins) items;
                    structure = raw;
                    scopeResult = args: collect (map (item: item.scopeResult (childArgs args)) items);
                    bindSelection =
                      args:
                      let
                        bindings = map (item: item.bindSelection (childArgs args)) items;
                      in
                      context:
                      validation.andThen (
                        values: accept ({ selected = true; } // bundle (builtins.filter (value: value.selected) values))
                      ) (validation.all (map (select: select context) bindings));
                  }
                ) (validation.all (lib.imap0 (index: value: prepare node.item (path ++ [ index ]) value) raw))
              )
              (
                fromDiagnostics (lib.optional (!builtins.isList raw) (
                  at path "collection-shape" "expected a list"
                )) true
              );
          "record-map" =
            validation.andThen
              (
                _:
                validation.andThen
                  (
                    _:
                    let
                      names = builtins.attrNames raw;
                    in
                    validation.andThen (
                      values:
                      let
                        items = named names values;
                      in
                      accept {
                        claimPaths = builtins.concatMap (name: items.${name}.claimPaths) names;
                        origins = lib.mapAttrs (_: item: item.origins) items;
                        structure = raw;
                        scopeResult = args: collect (map (name: items.${name}.scopeResult (childArgs args)) names);
                        bindSelection =
                          args:
                          let
                            bindings = lib.mapAttrs (_: item: item.bindSelection (childArgs args)) items;
                          in
                          context:
                          validation.andThen (
                            selectedValues:
                            let
                              selected = lib.filterAttrs (_: item: item.selected) (named names selectedValues);
                            in
                            accept {
                              selected = true;
                              value = lib.mapAttrs (_: item: item.value) selected;
                              metadata = lib.mapAttrs (_: item: item.metadata) selected;
                              origins = lib.mapAttrs (_: item: item.origins) selected;
                              prepared = lib.mapAttrs (_: item: item.prepared) selected;
                            }
                          ) (validation.all (map (name: bindings.${name} context) names));
                      }
                    ) (validation.all (map (name: prepare node.item (path ++ [ name ]) raw.${name}) names))
                  )
                  (
                    fromDiagnostics (map (name: at (path ++ [ name ]) "record-map-key" "invalid record map key") (
                      builtins.filter (name: !node.key name) (builtins.attrNames raw)
                    )) true
                  )
              )
              (
                fromDiagnostics (lib.optional (!builtins.isAttrs raw) (
                  at path "record-map-shape" "expected a record map"
                )) true
              );
          value = leaf;
          native = leaf;
        };
        leaf = accept {
          claimPaths = [ ];
          origins = path;
          structure = raw;
          scopeResult = _: accept true;
          bindSelection =
            _: _:
            let
              parsed = (schema path { value = node.field; }) { value = raw; };
              payload =
                if node.kind == "native" then
                  fromDiagnostics (lib.optional (!node.validate raw) (
                    at path "native-shape" "invalid ${node.owner} payload"
                  )) raw
                else
                  validation.andThen (result: accept result.value) (
                    fromAxiom (
                      parsed
                      // {
                        diagnostics = map (
                          diagnostic:
                          diagnostic
                          // {
                            primary = (diagnostic.primary or { }) // {
                              label = krisis.renderPath path;
                            };
                          }
                        ) parsed.diagnostics;
                      }
                    )
                  );
            in
            validation.andThen (
              value:
              accept {
                selected = true;
                inherit value;
                metadata = { };
                origins = path;
                prepared = { };
              }
            ) payload;
        };
      in
      cases.${node.kind};
in
{
  inherit prepare claimsOf;
}
