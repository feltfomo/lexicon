{
  lib,
  axiom,
  krisis,
  problem,
}:
rec {
  inherit (axiom) validation types sets;
  inherit
    (
      (krisis.mkReporter {
        formatHeader = count: "praxis: ${toString count} declaration error(s)";
        formatDiagnostic = krisis.renderPlain;
      })
    )
    finish
    ;
  text = value: if builtins.isBool value then (if value then "true" else "false") else toString value;
  envKey = value: lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] value);
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
      onRecord =
        value:
        diagnostic subject "${kind}-shape"
          "${kind} must be an attribute set, got ${krisis.safeShape value}";
      onUnknown =
        name: _:
        let
          suggestion = krisis.suggest name (builtins.attrNames fields);
        in
        problem (
          {
            code = "${kind}-field";
            message = "unknown ${kind} field '${name}'";
            primary.label = subject;
          }
          // lib.optionalAttrs (suggestion != null) { help = "use '${suggestion}'"; }
        );
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
