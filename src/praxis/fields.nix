{
  lib,
  axiom,
  krisis,
  problem,
}:
rec {
  inherit (axiom) validation types;
  diagnostic =
    subject: code: message:
    problem {
      inherit code message;
      primary.label = subject;
    };
  field = subject: code: message: validate: {
    inherit validate;
    onInvalid = _: _: diagnostic subject code message;
  };
  validateType =
    subject: code: type:
    krisis.validateType {
      inherit type;
      code = krisis.qualifyCode "praxis" code;
      label = subject;
    };
  typed = subject: code: type: { parse = validateType subject code type; };
  required =
    subject: code: message: validate:
    field subject code message validate
    // {
      required = true;
      onMissing = _: diagnostic subject code message;
    };
  closed =
    kind: subject: fields:
    axiom.schema.compile {
      inherit fields;
      onRecord = _: diagnostic subject "${kind}-shape" "${kind} must be an attribute set";
      onUnknown = name: _: diagnostic subject "${kind}-field" "unknown ${kind} field '${name}'";
    };
  nonEmpty = value: builtins.isString value && value != "";
  nullable = check: value: value == null || check value;
  relative =
    value:
    nonEmpty value
    && !lib.hasPrefix "/" value
    && builtins.all (part: part != "" && part != "." && part != "..") (lib.splitString "/" value);
  name = value: builtins.isString value && builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" value != null;
}
