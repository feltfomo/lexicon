{ lib, fields }:
let
  inherit (fields)
    validation
    diagnostic
    field
    required
    closed
    nonEmpty
    name
    types
    validateType
    ;
  parameterTypes = {
    inherit (types) string int bool;
    path = types.refine "non-empty runtime path string" types.string nonEmpty;
  };
  # malformed reference fields must not force the parameter value
  referenceType =
    let
      shape = types.refine "record containing only param" types.attrs (
        value: builtins.attrNames value == [ "param" ]
      );
      body = types.record { param = types.refine "command-style parameter name" types.string name; };
      validate = value: validation.andThen body.validate (shape.validate value);
    in
    body
    // {
      inherit validate;
      check = value: validation.isSuccess (validate value);
    };
  argumentType = types.oneOf "string or parameter reference" [
    types.string
    referenceType
  ];
  argumentsType = types.listOf argumentType;
  parameter =
    subject: raw:
    let
      shape = closed "parameter" subject {
        name =
          required subject "parameter-name"
            "parameter name must start with a letter and use letters, digits or '-'"
            (
              value:
              builtins.isString value
              && builtins.match "[a-zA-Z][a-zA-Z0-9-]*" value != null
              && !(builtins.elem value [
                "help"
                "yes"
                "plain"
              ])
            );
        description =
          field subject "parameter-description" "description must be a string" builtins.isString
          // {
            default = "";
          };
        type =
          field subject "parameter-type" "type must be string, int, bool or path"
            (types.enum (builtins.attrNames parameterTypes)).check
          // {
            default = "string";
          };
        positional =
          field subject "parameter-positional" "positional must be a boolean" builtins.isBool
          // {
            default = false;
          };
        required = field subject "parameter-required" "required must be a boolean" builtins.isBool // {
          default = false;
        };
        default.default = null;
      } raw;
    in
    validation.andThen (
      spec:
      let
        defaultResult = validateType "${subject}.default" "parameter-default" (types.nullOr
          parameterTypes.${spec.type}
        ) spec.default;
        diagnostics = validation.collect [
          defaultResult.diagnostics
          (validation.optional (spec.type == "bool" && spec.positional) (
            diagnostic subject "parameter-positional" "boolean parameters must be named flags"
          ))
          (validation.optional (spec.required && spec.default != null) (
            diagnostic subject "parameter-default" "required parameters cannot have defaults"
          ))
        ];
      in
      validation.fromDiagnostics diagnostics (
        spec
        // {
          default =
            if defaultResult.value == null then
              null
            else if builtins.isBool defaultResult.value then
              (if defaultResult.value then "true" else "false")
            else
              toString defaultResult.value;
        }
      )
    ) shape;
  envKey = value: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] value);
in
{
  inherit
    parameter
    envKey
    argumentType
    argumentsType
    ;
  argument = argumentType.check;
  arguments = argumentsType.check;
  references =
    subject: parameters: args:
    lib.concatMap (
      arg:
      validation.optional (builtins.isAttrs arg && !(builtins.hasAttr arg.param parameters)) (
        diagnostic subject "parameter-reference" "argument refers to an undeclared parameter"
      )
    ) args;
}
