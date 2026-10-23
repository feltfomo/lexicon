{
  lib,
  axiom,
  krisis,
}:
let
  registration = import ./definitions.nix { inherit lib axiom krisis; };
  report = import ./report.nix { inherit lib axiom krisis; };
  outputCompiler = import ./outputs.nix { inherit lib axiom krisis; };
  inherit (report) at checked finish;
  inherit (axiom) validation;
  empty = {
    nixos = [ ];
    homeManager = [ ];
    resources = [ ];
  };
  contextForScope =
    scope: context: if scope == "system" then context // { user = null; } else context;
  configure =
    args:
    let
      environment = registration.configure args;
      traversal = import ./traversal.nix {
        inherit
          lib
          axiom
          krisis
          environment
          ;
      };
      rootNode = {
        kind = "record";
        fields = { };
        children = lib.mapAttrs (_: block: block.node) environment.blocks.byKey;
        prepare = _: { };
      };
      bind =
        {
          direct ? false,
          roster ? null,
          resolvers ? null,
        }:
        let
          resolveFor =
            scope:
            let
              resolver =
                if direct then
                  _: _: { }
                else if resolvers != null then
                  if scope == "system" then resolvers.resolveSystem else resolvers.resolvePrepared
                else
                  environment.ownerships.resolverFor {
                    inherit roster scope;
                    projection = "prepared";
                  };
            in
            units:
            let
              selected = resolver units;
            in
            context: selected (contextForScope scope context);
          prepares = lib.genAttrs [ "user" "system" ] resolveFor;
          prepare =
            declaration:
            let
              tree = traversal.prepare rootNode [ ] declaration;
              rootClaims = traversal.claimsOf declaration;
              rootMetadata = (report.schema [ "metadata" ] environment.metadataFields) (
                declaration.metadata or { }
              );
              forScope =
                scope: requested:
                let
                  resolve = prepares.${scope};
                  rootChain = [ (environment.ownerships.projectClaims scope rootClaims) ];
                  rootSelection =
                    if direct then
                      _: { lexiconSelected = true; }
                    else
                      resolve [
                        (
                          (builtins.head rootChain)
                          // {
                            lexiconSelected = true;
                            label = "$";
                          }
                        )
                      ];
                  blocks = map (
                    block:
                    let
                      active =
                        declaration ? ${block.name}
                        && (block.scope == scope || block.scope == "split")
                        && builtins.any (name: builtins.elem name requested) block.outputs;
                      selectionArgs = {
                        inherit scope direct resolve;
                        outputs = requested;
                        ancestors = rootChain;
                        project = block.scope == "split";
                      };
                      child = tree.children.${block.name};
                      select = child.bindSelection selectionArgs;
                      intent = krisis.withErrorContext "lexicon resource intent for ${block.name}" (
                        block.resourceIntent declaration.${block.name}
                      );
                      intentResult = validation.fromDiagnostics (lib.optional (!builtins.isBool intent) (
                        at [ block.name ] "resource-intent-shape" "resource intent must be a boolean"
                      )) intent;
                    in
                    {
                      scopeResult =
                        if declaration ? ${block.name} && (block.scope == scope || block.scope == "split") then
                          child.scopeResult selectionArgs
                        else
                          validation.success true;
                      compile =
                        context:
                        if !active then
                          validation.success empty
                        else
                          validation.andThen (
                            selected:
                            if !selected.selected then
                              validation.success empty
                            else
                              validation.andThen (
                                resourceIntent:
                                validation.andThen
                                  (
                                    _:
                                    krisis.withErrorContext "lexicon lowering block ${block.name}" (
                                      outputCompiler.validate {
                                        definition = block;
                                        inherit (environment) annotationNames;
                                        inherit scope resourceIntent requested;
                                        path = [ block.name ];
                                        output = block.lower {
                                          inherit (selected)
                                            value
                                            metadata
                                            origins
                                            prepared
                                            ;
                                          inherit context;
                                        };
                                      }
                                    )
                                  )
                                  (
                                    validation.fromDiagnostics (lib.optional
                                      (scope == "user" && resourceIntent && (context.user or null) == null)
                                      (at [ block.name ] "resource-user" "resource-producing declarations require a concrete user target")
                                    ) true
                                  )
                              ) intentResult
                          ) (select context);
                    }
                  ) environment.blocks.registrations;
                  scoped = validation.sequence (map (block: block.scopeResult) blocks);
                in
                rawContext:
                let
                  context = rawContext // {
                    inherit scope;
                  };
                in
                validation.andThen (
                  _:
                  if !((rootSelection context).lexiconSelected or false) then
                    validation.success empty
                  else
                    validation.map2 (
                      _: results:
                      lib.genAttrs (builtins.attrNames empty) (name: builtins.concatMap (result: result.${name}) results)
                    ) rootMetadata (validation.sequence (map (block: block.compile context) blocks))
                ) scoped;

              outputNames = [
                "nixos"
                "homeManager"
                "resources"
              ];
              outputSets = lib.foldr (name: sets: sets ++ map (set: [ name ] ++ set) sets) [ [ ] ] outputNames;
              scopes = lib.genAttrs [ "user" "system" ] (
                scope:
                builtins.listToAttrs (
                  map (outputs: {
                    name = builtins.toJSON outputs;
                    value = forScope scope outputs;
                  }) outputSets
                )
              );
              validate =
                {
                  scope,
                  context,
                  outputs ? [
                    "nixos"
                    "homeManager"
                    "resources"
                  ],
                }:
                validation.andThen
                  (
                    _:
                    scopes.${scope}.${builtins.toJSON (builtins.filter (name: builtins.elem name outputs) outputNames)}
                      context
                  )
                  (
                    validation.fromDiagnostics (
                      lib.optional (
                        !builtins.elem scope [
                          "user"
                          "system"
                        ]
                      ) (at [ ] "scope" "scope must be user or system")
                      ++ lib.optional (
                        !builtins.isList outputs || !builtins.all (name: builtins.elem name outputNames) outputs
                      ) (at [ "outputs" ] "output-projection" "outputs must name supported contribution kinds")
                    ) true
                  );
              directCheck = checked (lib.optionals direct (
                map (
                  path: at path "direct-annotation" "direct binding rejects ownership annotations"
                ) tree.claimPaths
              )) true;
            in
            builtins.seq (finish tree.structural) (
              builtins.seq directCheck {
                inherit validate;
                compile = args: finish (validate args);
                structure = declaration;
              }
            );
        in
        {
          inherit prepare;
        };
    in
    environment // { inherit bind; };
in
{
  inherit configure contextForScope;
  inherit (registration) definitions;
}
