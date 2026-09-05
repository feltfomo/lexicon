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
                "non-interactive"
                "output"
                "concise"
                "verbose"
                "quiet"
                "json"
                "color"
                "no-progress"
                "notify"
                "bell"
                "all"
                "complete"
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
        env =
          field subject "parameter-env" "env must be a valid environment name" (
            fields.nullable (v: builtins.isString v && lib.strings.isValidPosixName v)
          )
          // {
            default = null;
          };
        short =
          field subject "parameter-short" "short must be one unreserved letter" (
            fields.nullable (
              v:
              builtins.isString v
              && builtins.match "[a-zA-Z]" v != null
              && !(builtins.elem v [
                "h"
                "y"
                "q"
                "v"
              ])
            )
          )
          // {
            default = null;
          };
        sensitive = field subject "parameter-sensitive" "sensitive must be boolean" builtins.isBool // {
          default = false;
        };
        choices.default = [ ];
        default.default = null;
      } raw;
    in
    validation.andThen (
      spec:
      if
        spec.sensitive && (raw ? default || raw ? choices || spec.positional || spec.type != "string")
      then
        validation.failure [
          (diagnostic subject "parameter-sensitive"
            "sensitive parameters must be named strings without static defaults or choices"
          )
        ]
      else
        let
          choiceResult = validateType "${subject}.choices" "parameter-choices" (types.listOf
            parameterTypes.${spec.type}
          ) spec.choices;
          defaultResult = validateType "${subject}.default" "parameter-default" (types.nullOr
            parameterTypes.${spec.type}
          ) spec.default;
          diagnostics = validation.collect [
            defaultResult.diagnostics
            choiceResult.diagnostics
            (validation.optional (
              choiceResult.diagnostics == [ ]
              &&
                builtins.length spec.choices
                != builtins.length (builtins.attrNames (fields.sets.index (map fields.text spec.choices)))
            ) (diagnostic subject "parameter-choices" "choices must be unique"))
            (validation.optional (
              choiceResult.diagnostics == [ ]
              && defaultResult.diagnostics == [ ]
              && spec.choices != [ ]
              && spec.default != null
              && !(builtins.elem spec.default spec.choices)
            ) (diagnostic subject "parameter-default" "default must be one of the choices"))
            (validation.optional (spec.positional && spec.short != null) (
              diagnostic subject "parameter-short" "positional parameters cannot have a short flag"
            ))
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
            choices = map fields.text choiceResult.value;
            default = if defaultResult.value == null then null else fields.text defaultResult.value;
          }
        )
    ) shape;
  inherit (fields) envKey;
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
  conditionDiagnostics =
    subject: parameters: values:
    lib.concatMap (
      name:
      if !(builtins.hasAttr name parameters) || parameters.${name}.sensitive then
        [ ]
      else
        let
          spec = parameters.${name};
          result =
            validateType "${subject}.when.parameters.${name}" "condition" parameterTypes.${spec.type}
              values.${name};
        in
        result.diagnostics
        ++ validation.optional (
          result.diagnostics == [ ]
          && spec.choices != [ ]
          && !(builtins.elem (fields.text values.${name}) spec.choices)
        ) (diagnostic subject "condition" "parameter condition must use a declared choice")
    ) (builtins.attrNames values);
  references =
    subject: parameters: args:
    lib.concatMap (
      arg:
      validation.optional (builtins.isAttrs arg && !(builtins.hasAttr arg.param parameters)) (
        diagnostic subject "parameter-reference" "argument refers to an undeclared parameter"
      )
    ) args;
}
