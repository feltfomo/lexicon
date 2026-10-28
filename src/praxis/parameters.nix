{ lib, fields }:
let
  inherit (fields)
    effects
    checked
    reject
    diagnostic
    field
    required
    closed
    typeChecks
    ;
  choiceCheck = (typeChecks "parameter-choices").choices;
  defaultCheck = (typeChecks "parameter-default").default;
  conditionCheck = (typeChecks "condition").scalar;
  parameter =
    subject: raw:
    let
      shape = closed "parameter" subject {
        name =
          required subject "parameter-name"
            "parameter name must start with a letter and use letters, digits or '-'"
            (value: builtins.isString value && builtins.match "[a-zA-Z][a-zA-Z0-9-]*" value != null);
        description =
          field subject "parameter-description" "description must be a string" builtins.isString
          // {
            default = "";
          };
        type =
          field subject "parameter-type" "type must be string, int, bool or path" (
            value:
            builtins.isString value
            && builtins.elem value [
              "string"
              "int"
              "bool"
              "path"
            ]
          )
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
          field subject "parameter-short" "short must be one letter" (
            fields.nullable (v: builtins.isString v && builtins.match "[a-zA-Z]" v != null)
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
    checked.andThen (
      spec:
      if
        spec.sensitive && (raw ? default || raw ? choices || spec.positional || spec.type != "string")
      then
        reject [
          (diagnostic subject "parameter-sensitive"
            "sensitive parameters must be named strings without static defaults or choices"
          )
        ]
      else
        let
          choiceResult = choiceCheck "${subject}.choices" spec.type spec.choices;
          defaultResult = defaultCheck "${subject}.default" spec.type spec.default;
          diagnostics = builtins.concatLists [
            defaultResult.diagnostics
            choiceResult.diagnostics
            (lib.optional (
              choiceResult.diagnostics == [ ]
              &&
                builtins.length spec.choices
                != builtins.length (builtins.attrNames (fields.sets.index (map fields.text spec.choices)))
            ) (diagnostic subject "parameter-choices" "choices must be unique"))
            (lib.optional (
              choiceResult.diagnostics == [ ]
              && defaultResult.diagnostics == [ ]
              && spec.choices != [ ]
              && spec.default != null
              && !(builtins.elem spec.default spec.choices)
            ) (diagnostic subject "parameter-default" "default must be one of the choices"))
            (lib.optional (spec.positional && spec.short != null) (
              diagnostic subject "parameter-short" "positional parameters cannot have a short flag"
            ))
            (lib.optional (spec.type == "bool" && spec.positional) (
              diagnostic subject "parameter-positional" "boolean parameters must be named flags"
            ))
            (lib.optional (spec.required && spec.default != null) (
              diagnostic subject "parameter-default" "required parameters cannot have defaults"
            ))
          ];
        in
        effects.fromDiagnostics diagnostics (
          spec
          // {
            choices = map fields.text choiceResult.value;
            default = if defaultResult.value == null then null else fields.text defaultResult.value;
          }
        )
    ) (effects.fromAxiom shape);
  inherit (fields) envKey;
in
{
  inherit
    parameter
    envKey
    ;
  conditionDiagnostics =
    subject: parameters: values:
    lib.concatMap (
      name:
      if !(builtins.hasAttr name parameters) || parameters.${name}.sensitive then
        [ ]
      else
        let
          spec = parameters.${name};
          result = conditionCheck "${subject}.when.parameters.${name}" spec.type values.${name};
        in
        result.diagnostics
        ++ lib.optional (
          result.diagnostics == [ ]
          && spec.choices != [ ]
          && !(builtins.elem (fields.text values.${name}) spec.choices)
        ) (diagnostic subject "condition" "parameter condition must use a declared choice")
    ) (builtins.attrNames values);
  references =
    subject: parameters: args:
    lib.concatMap (
      arg:
      lib.optional (builtins.isAttrs arg && !(builtins.hasAttr arg.param parameters)) (
        diagnostic subject "parameter-reference" "argument refers to an undeclared parameter"
      )
    ) args;
}
