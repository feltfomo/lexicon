{
  lib,
  axiom,
  krisis,
}:
let
  report = import ./report.nix { inherit lib axiom krisis; };
  inherit (report) schema field at;
  inherit (krisis.effects)
    native
    accept
    fromAxiom
    fromDiagnostics
    resultOf
    ;
  inherit (native) validation;
  origin =
    value:
    builtins.isList value
    && builtins.all (part: builtins.isString part || (builtins.isInt part && part >= 0)) value;
  nativeSchema =
    path:
    schema path {
      module = field path "module" (
        value: builtins.isAttrs value || builtins.isFunction value || builtins.isPath value
      );
      origin = field path "origin" origin;
    };
  resourceSchema =
    path:
    schema path {
      kind = field path "kind" (
        value:
        builtins.elem value [
          "file"
          "external-link"
          "directory"
          "theme"
        ]
      );
      value = field path "value" builtins.isAttrs;
      origin = field path "origin" origin;
      prepared = { };
    };
  validateComputation =
    {
      definition,
      scope,
      resourceIntent,
      path,
      output,
      annotationNames,
      requested ? [
        "nixos"
        "homeManager"
        "resources"
      ],
    }:
    let
      shaped =
        (schema path (
          lib.genAttrs [ "nixos" "homeManager" "resources" ] (_: {
            default = [ ];
            validate = builtins.isList;
            onInvalid = _: _: at path "output-shape" "contributions must be a list";
          })
        ))
          output;
    in
    validation.andThen (
      contributions:
      let
        nonempty = builtins.filter (name: contributions.${name} != [ ]) (builtins.attrNames contributions);
        unsupported = builtins.filter (name: !builtins.elem name definition.outputs) nonempty;
        incompatible = builtins.filter (
          name: (name == "nixos" && scope != "system") || (name != "nixos" && scope != "user")
        ) nonempty;
        errors =
          map (
            name:
            at (
              path ++ [ name ]
            ) "output-projection" "contribution is outside the requested native bridge projection"
          ) (builtins.filter (name: !builtins.elem name requested) nonempty)
          ++ map (
            name: at (path ++ [ name ]) "undeclared-output" "definition did not declare this contribution"
          ) unsupported
          ++ map (
            name: at (path ++ [ name ]) "output-scope" "contribution is unavailable in ${scope} scope"
          ) incompatible
          ++ lib.optional (contributions.resources != [ ] && !resourceIntent) (
            at (
              path ++ [ "resources" ]
            ) "resource-intent" "resource output contradicts structural resource intent"
          );
        validateList =
          name: parser:
          validation.all (
            lib.imap0 (
              index: value:
              (parser (
                path
                ++ [
                  name
                  index
                ]
              ))
                value
            ) contributions.${name}
          );
        resource =
          path: value:
          validation.andThen (
            plan:
            fromDiagnostics (map (
              name:
              at (
                path
                ++ [
                  "value"
                  name
                ]
              ) "output-annotation" "lowering cannot introduce ownership or metadata annotations"
            ) (builtins.filter (name: builtins.elem name annotationNames) (builtins.attrNames plan.value))) plan
          ) (fromAxiom ((resourceSchema path) value));
        parseNative = path: value: fromAxiom ((nativeSchema path) value);
        items =
          validation.andThen
            (
              values:
              accept {
                nixos = builtins.elemAt values 0;
                homeManager = builtins.elemAt values 1;
                resources = builtins.elemAt values 2;
              }
            )
            (
              validation.all [
                (validateList "nixos" parseNative)
                (validateList "homeManager" parseNative)
                (validateList "resources" resource)
              ]
            );
      in
      validation.andThen (_: items) (fromDiagnostics errors true)
    ) (fromAxiom shaped);
  validate = args: resultOf (validateComputation args);
in
{
  inherit validate validateComputation origin;
}
