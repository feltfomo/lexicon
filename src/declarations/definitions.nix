{
  lib,
  axiom,
  krisis,
}:
let
  report = import ./report.nix { inherit lib axiom krisis; };
  inherit (report)
    at
    field
    schema
    finish
    checked
    ;
  axes = import ../ownerships/axes.nix { inherit lib axiom krisis; };
  constructors = {
    record = args: args // { kind = "record"; };
    collection = args: args // { kind = "collection"; };
    recordMap = args: args // { kind = "record-map"; };
    value = field: {
      kind = "value";
      inherit field;
    };
    native = args: args // { kind = "native"; };
    forOutputs = outputs: item: {
      kind = "projection";
      inherit outputs item;
    };
    recursive = body: {
      kind = "recursive";
      inherit body;
    };
    inherit (axes) mkSetDescriptor mkPredicateDescriptor;
  };
  optional = validate: {
    inherit validate;
    onInvalid = _: _: at [ ] "definition-shape" "invalid definition field";
  };
  forceFields = path: fields: builtins.seq ((schema path fields) null).diagnostics fields;

  compileNode =
    annotations: references: path: raw:
    if builtins.isAttrs raw && (raw.kind or null) == "reference" then
      let
        reference = finish (
          (schema path {
            kind = { };
            name = field path "name" builtins.isString;
          })
            raw
        );
      in
      checked
        (lib.optional (!(references ? ${reference.name})) (
          at path "recursive-reference" "reference is outside its recursive binder"
        ))
        {
          kind = "reference";
          target = references.${reference.name};
          validated = true;
        }
    else if builtins.isAttrs raw && (raw.kind or null) == "recursive" then
      let
        binder = finish (
          (schema path {
            kind = { };
            body = field path "body" builtins.isFunction;
          })
            raw
        );
        name = krisis.renderPath path;
        body = binder.body {
          kind = "reference";
          inherit name;
        };
        productive =
          node:
          if !builtins.isAttrs node then
            false
          else if (node.kind or null) == "projection" then
            productive (node.item or { })
          else
            builtins.elem (node.kind or null) [
              "record"
              "collection"
              "record-map"
              "value"
              "native"
            ];
        compiled = checked (lib.optional (!productive body) (
          at path "recursive-body" "recursive body must consume authored data before a reference"
        )) (compileNode annotations (references // { ${name} = compiled; }) (path ++ [ "body" ]) body);
      in
      compiled
    else
      let
        head = finish (
          (axiom.schema.compile {
            allowUnknown = true;
            onRecord = _: at path "node-definition" "node definition must be a record";
            fields.kind = field path "kind" (
              value:
              builtins.elem value [
                "record"
                "collection"
                "record-map"
                "value"
                "native"
                "projection"
              ]
            );
          })
            raw
        );
        forms = {
          record = {
            fields = (optional builtins.isAttrs) // {
              default = { };
            };
            children = (optional builtins.isAttrs) // {
              default = { };
            };
            prepare = (optional builtins.isFunction) // {
              default = _: { };
            };
          };
          collection = {
            item = field path "item" builtins.isAttrs;
            contextual = (optional builtins.isBool) // {
              default = false;
            };
          };
          "record-map" = {
            item = field path "item" builtins.isAttrs;
            key = field path "key" builtins.isFunction;
          };
          projection = {
            item = field path "item" builtins.isAttrs;
            outputs = field path "outputs" (
              v:
              builtins.isList v
              && v != [ ]
              && builtins.all (
                name:
                builtins.elem name [
                  "nixos"
                  "homeManager"
                  "resources"
                ]
              ) v
            );
          };
          value.field = field path "field" builtins.isAttrs;
          native = {
            owner = field path "owner" report.nonempty;
            validate = field path "validate" builtins.isFunction;
          };
        };
        node = finish ((schema path ({ kind = { }; } // forms.${head.kind})) head);
        recordNames = builtins.attrNames (node.fields or { }) ++ builtins.attrNames (node.children or { });
        collisions = builtins.filter (name: builtins.elem name annotations) recordNames;
        names =
          if node.kind == "record" then
            report.registry path (map (name: { inherit name; }) recordNames)
          else
            null;
        children = lib.mapAttrs (
          name:
          compileNode annotations references (
            path
            ++ [
              "children"
              name
            ]
          )
        ) (node.children or { });
        compiled = {
          record = node // {
            fields = forceFields path node.fields;
            inherit children;
          };
          collection = node // {
            item = compileNode annotations references (path ++ [ "item" ]) node.item;
          };
          "record-map" = node // {
            item = compileNode annotations references (path ++ [ "item" ]) node.item;
          };
          projection = node // {
            item = compileNode annotations references (path ++ [ "item" ]) node.item;
          };
          value = node // {
            field = (forceFields path { value = node.field; }).value;
          };
          native = node;
        };
        validation =
          if node.kind == "record" then
            builtins.seq names (
              checked
                (map (
                  name: at path "annotation-collision" "domain field ${name} collides with a common annotation"
                ) collisions)
                (
                  builtins.seq (forceFields path node.fields) (
                    builtins.deepSeq (lib.mapAttrs (_: child: child.validated) children) true
                  )
                )
            )
          else if
            builtins.elem node.kind [
              "collection"
              "record-map"
              "projection"
            ]
          then
            compiled.${node.kind}.item.validated
          else if node.kind == "value" then
            builtins.seq compiled.value.field true
          else
            true;
      in
      builtins.seq validation (compiled.${node.kind} // { validated = true; });

  configure =
    {
      extensions ? [ ],
      blocks ? [ ],
    }:
    let
      extensionSchema =
        path:
        schema path {
          name = field path "name" report.nonempty;
          blocks = (optional builtins.isList) // {
            default = [ ];
          };
          ownership = (optional builtins.isList) // {
            default = [ ];
          };
          relations = (optional builtins.isList) // {
            default = [ ];
          };
          metadata = (optional builtins.isList) // {
            default = [ ];
          };
        };
      checkedExtensions = checked (lib.optional (!builtins.isList extensions) (
        at [ ] "extensions" "extensions must be a list"
      )) extensions;
      instances = finish (
        axiom.validation.sequence (
          lib.imap0 (
            index: extension:
            let
              path = [
                "extensions"
                index
              ];
            in
            if !builtins.isFunction extension then
              axiom.validation.failure [ (at path "extension" "extension must be a function") ]
            else
              krisis.withErrorContext "lexicon extension at ${krisis.renderPath path}" (
                (extensionSchema path) (extension {
                  inherit lib axiom krisis;
                  definitions = constructors;
                })
              )
          ) checkedExtensions
        )
      );
      extensionRegistry = report.registry [ "extensions" ] instances;
      descriptors = axes.validateDescriptors (
        axes.descriptors ++ builtins.concatMap (extension: extension.ownership) instances
      );
      descriptorSet = axes.compileDescriptors descriptors;
      relations = axes.validateRelations descriptors (
        axes.relations ++ builtins.concatMap (extension: extension.relations) instances
      );
      ownerships = import ../ownerships {
        inherit
          lib
          axiom
          krisis
          descriptors
          relations
          ;
      };
      metadataEntries = builtins.concatMap (extension: extension.metadata) instances;
      metadataShapes = finish (
        axiom.validation.sequence (
          lib.imap0 (
            index: entry:
            (schema [ "metadata" index ] {
              name = field [ "metadata" index ] "name" report.nonempty;
              field = field [ "metadata" index ] "field" builtins.isAttrs;
            })
              entry
          ) metadataEntries
        )
      );
      metadataRegistry = report.registry [ "metadata" ] metadataShapes;
      metadataFields = lib.mapAttrs (_: entry: entry.field) metadataRegistry.byKey;
      checkedMetadata = forceFields [ "metadata" ] metadataFields;
      annotationNames = descriptorSet.claimKeys ++ [ "metadata" ];
      forbiddenClaims = builtins.filter (
        name:
        builtins.elem name [
          "metadata"
          "value"
          "children"
          "label"
          "source"
          "mergeProfile"
        ]
      ) descriptorSet.claimKeys;
      blockSchema =
        path:
        schema path {
          name = field path "name" report.nonempty;
          scope = field path "scope" (
            value:
            builtins.elem value [
              "user"
              "system"
              "split"
            ]
          );
          outputs = field path "outputs" (
            value:
            builtins.isList value
            && builtins.all (
              name:
              builtins.elem name [
                "nixos"
                "homeManager"
                "resources"
              ]
            ) value
            && lib.unique value == value
          );
          node = field path "node" builtins.isAttrs;
          lower = field path "lower" builtins.isFunction;
          resourceIntent = optional builtins.isFunction;
        };
      rawBlocks = blocks ++ builtins.concatMap (extension: extension.blocks) instances;
      shapedBlocks = finish (
        axiom.validation.sequence (
          lib.imap0 (
            index: block:
            (blockSchema [
              "blocks"
              index
            ])
              block
          ) rawBlocks
        )
      );
      registeredBlocks = report.registry [ "blocks" ] shapedBlocks;
      blockCollisions = builtins.filter (name: builtins.elem name annotationNames) registeredBlocks.keys;
      ambiguous =
        allowed: node:
        if node.kind == "projection" then
          ambiguous (builtins.filter (name: builtins.elem name node.outputs) allowed) node.item
        else if node.kind == "reference" then
          false
        else if node.kind == "native" then
          builtins.elem "homeManager" allowed && builtins.elem "resources" allowed
        else if node.kind == "collection" then
          (node.contextual && builtins.elem "homeManager" allowed && builtins.elem "resources" allowed)
          || ambiguous allowed node.item
        else if node.kind == "record-map" then
          ambiguous allowed node.item
        else if node.kind == "record" then
          builtins.any (ambiguous allowed) (builtins.attrValues node.children)
        else
          false;
      compiledBlocks = map (
        block:
        block
        // {
          node = compileNode annotationNames { } [ "blocks" block.name "node" ] block.node;
          resourceIntent = block.resourceIntent or (_: builtins.elem "resources" block.outputs);
        }
      ) shapedBlocks;
      valid = builtins.seq extensionRegistry (
        builtins.seq relations (
          builtins.seq checkedMetadata (
            checked (
              map (name: at [ ] "annotation-collision" "ownership key ${name} is reserved") forbiddenClaims
              ++ map (
                name: at [ ] "block-collision" "block ${name} collides with a common annotation"
              ) blockCollisions
              ++ map (
                block:
                at [
                  "blocks"
                  block.name
                ] "output-projection" "mixed-output contextual and native branches require forOutputs"
              ) (builtins.filter (block: ambiguous block.outputs block.node) compiledBlocks)
            ) (builtins.deepSeq (map (block: block.node.validated) compiledBlocks) true)
          )
        )
      );
    in
    builtins.seq valid {
      inherit
        ownerships
        descriptors
        descriptorSet
        relations
        metadataFields
        annotationNames
        ;
      blocks = report.registry [ "blocks" ] compiledBlocks;
      definitions = constructors;
    };
in
{
  inherit configure;
  definitions = constructors;
}
