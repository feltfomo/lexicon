{ lib, fields }:
let
  inherit (fields)
    validation
    diagnostic
    field
    closed
    nonEmpty
    nullable
    ;
  strings = value: builtins.isList value && builtins.all builtins.isString value;
  enum = values: value: builtins.elem value values;
  scalar = value: builtins.isString value || builtins.isInt value || builtins.isBool value;
  inherit (fields) text;
  notifications =
    subject:
    closed "notifications" subject {
      success = field subject "ui" "success must be boolean" builtins.isBool;
      failure = field subject "ui" "failure must be boolean" builtins.isBool;
      bell = field subject "ui" "bell must be boolean" builtins.isBool;
      desktop = field subject "ui" "desktop must be boolean" builtins.isBool;
      command = field subject "ui" "notification command must be non-empty literal argv" (
        v: strings v && v != [ ] && nonEmpty (builtins.head v)
      );
    };
  ui =
    subject:
    closed "ui" subject {
      output = field subject "ui" "unknown output mode" (enum [
        "concise"
        "verbose"
        "quiet"
        "plain"
        "json"
      ]);
      color = field subject "ui" "color must be auto, always or never" (enum [
        "auto"
        "always"
        "never"
      ]);
      progress = field subject "ui" "progress must be boolean" builtins.isBool;
      notifications.parse = notifications subject;
    };
  condition =
    subject: raw:
    let
      shape = closed "condition" subject {
        parameters =
          field subject "condition" "parameters must map names to literal values" (
            v: builtins.isAttrs v && builtins.all scalar (builtins.attrValues v)
          )
          // {
            default = { };
          };
        platforms =
          field subject "condition" "platforms must be a list of non-empty strings" (
            v: strings v && builtins.all nonEmpty v
          )
          // {
            default = [ ];
          };
        env =
          field subject "condition" "env must map environment names to strings or null" (
            v:
            builtins.isAttrs v
            && builtins.all lib.strings.isValidPosixName (builtins.attrNames v)
            && builtins.all (nullable builtins.isString) (builtins.attrValues v)
          )
          // {
            default = { };
          };
      } raw;
    in
    shape;
  prompt =
    subject: raw:
    let
      shape = closed "prompt" subject {
        type =
          field subject "prompt" "prompt type must be confirm, acknowledge or select" (enum [
            "confirm"
            "acknowledge"
            "select"
          ])
          // {
            default = "confirm";
          };
        message = fields.required subject "prompt" "prompt message is required" nonEmpty;
        name =
          field subject "prompt" "prompt name must be a parameter-style name" (
            nullable (v: builtins.isString v && builtins.match "[a-zA-Z][a-zA-Z0-9-]*" v != null)
          )
          // {
            default = null;
          };
        acknowledgement =
          field subject "prompt" "acknowledgement must be a non-empty string" (nullable nonEmpty)
          // {
            default = null;
          };
        choices =
          field subject "prompt" "choices must be non-empty strings" (v: strings v && builtins.all nonEmpty v)
          // {
            default = [ ];
          };
        default.default = null;
      } raw;
    in
    validation.andThen (
      spec:
      validation.fromDiagnostics (validation.collect [
        (validation.optional (spec.type == "select" && (spec.choices == [ ] || spec.name == null)) (
          diagnostic subject "prompt" "selection needs choices and a name"
        ))
        (validation.optional (
          builtins.length spec.choices != builtins.length (fields.sets.unique spec.choices)
        ) (diagnostic subject "prompt" "prompt choices must be unique"))
        (validation.optional (spec.type == "acknowledge" && spec.acknowledgement == null) (
          diagnostic subject "prompt" "typed acknowledgement needs acknowledgement text"
        ))
        (validation.optional (spec.type != "select" && spec.choices != [ ]) (
          diagnostic subject "prompt" "choices are only valid for selection"
        ))
        (validation.optional (spec.type != "acknowledge" && spec.acknowledgement != null) (
          diagnostic subject "prompt" "acknowledgement is only valid for typed prompts"
        ))
        (validation.optional (
          spec.default != null
          && !(
            if spec.type == "select" then
              builtins.elem spec.default spec.choices
            else
              spec.type == "confirm" && builtins.isBool spec.default
          )
        ) (diagnostic subject "prompt" "default must match the prompt type and choices"))
      ]) (spec // { default = if spec.default == null then null else text spec.default; })
    ) shape;
  group =
    subject:
    closed "parameter-group" subject {
      type = fields.required subject "parameter-group" "group type must be exclusive or together" (enum [
        "exclusive"
        "together"
      ]);
      parameters =
        fields.required subject "parameter-group" "a group needs at least two distinct parameter names"
          (
            v:
            strings v && builtins.length v >= 2 && builtins.length v == builtins.length (fields.sets.unique v)
          );
    };
in
{
  inherit
    ui
    condition
    prompt
    group
    strings
    text
    ;
  uiField = subject: {
    parse = ui subject;
    default = { };
  };
  conditionField = subject: {
    parse = condition subject;
    default = { };
  };
  timeoutField =
    subject:
    field subject "timeout" "timeout must be positive seconds, at most one week" (
      nullable (v: builtins.isInt v && v > 0 && v <= 604800)
    )
    // {
      default = null;
    };
}
