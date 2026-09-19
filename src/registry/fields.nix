# one diagnostic factory, one reporter, and the field helpers every registry
# schema shares. axiom's own registry module is only ever reached through the
# axiom attrset, so a bare registry in this source always means this subsystem.
{
  lib,
  axiom,
  krisis,
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "registry";
  };

  reporter = krisis.mkReporter {
    formatHeader = count: "registry: ${toString count} error(s)";
    formatDiagnostic = krisis.renderPlain;
  };

  diagnostic =
    subject: code: message:
    problem {
      inherit code message;
      primary.label = subject;
    };

  # every closed vocabulary here answers an unknown name the same way. a typo is
  # told what it probably meant rather than handed the whole legal set.
  hinted =
    subject: code: message: name: candidates:
    let
      match = krisis.suggest name candidates;
    in
    problem (
      {
        inherit code message;
        primary.label = subject;
      }
      // lib.optionalAttrs (match != null) { help = "did you mean '${match}'?"; }
    );

  field = subject: code: message: validate: {
    inherit validate;
    onInvalid = _record: _value: diagnostic subject code message;
  };

  required =
    subject: code: message: validate:
    field subject code message validate
    // {
      required = true;
      onMissing = _record: diagnostic subject code message;
    };

  closed =
    kind: subject: declaredFields:
    axiom.schema.compile {
      fields = declaredFields;
      onRecord =
        value:
        diagnostic subject "${kind}-shape"
          "${kind} must be an attribute set, got ${krisis.safeShape value}";
      onUnknown =
        name: _value:
        hinted subject "${kind}-field" "unknown ${kind} field '${name}'" name (
          builtins.attrNames declaredFields
        );
    };

  nonEmpty = value: builtins.isString value && value != "";
  nullable = predicate: value: value == null || predicate value;
  qualifiedPart = value: nonEmpty value && !lib.hasInfix "/" value;
  nameList =
    value: builtins.isList value && builtins.all nonEmpty value && axiom.sets.unique value == value;
  absolute = value: nonEmpty value && lib.hasPrefix "/" value;
  stringAttrs =
    value: builtins.isAttrs value && builtins.all builtins.isString (builtins.attrValues value);
in
{
  inherit
    problem
    diagnostic
    hinted
    field
    required
    closed
    nonEmpty
    nullable
    qualifiedPart
    nameList
    absolute
    stringAttrs
    ;
  inherit (reporter) finish fail failOne;
}
