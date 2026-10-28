{
  lib,
  axiom,
  krisis,
  problem,
}:
rec {
  inherit lib;
  inherit (krisis) effects;
  checked = effects.native.validation;
  mapChecked = f: checked.andThen (value: effects.accept (f value));
  map2Checked =
    f: left: right:
    mapChecked (values: f (builtins.elemAt values 0) (builtins.elemAt values 1)) (
      checked.all [
        left
        right
      ]
    );
  reject = diagnostics: effects.fromDiagnostics diagnostics null;
  checkedClosed =
    kind: subject: fields: value:
    effects.fromAxiom (closed kind subject fields value);
  finishChecked = effects.finishWithReporter (
    krisis.effects.reporter {
      formatHeader = count: "praxis: ${toString count} declaration error(s)";
      formatDiagnostic = krisis.renderPlain;
    }
  );
  inherit (axiom) sets;
  typeChecks = import ./type-checks.nix {
    inherit
      lib
      axiom
      krisis
      diagnostic
      nonEmpty
      name
      ;
  };
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
  routeName = value: builtins.isString value && builtins.all name (lib.splitString "." value);
}
