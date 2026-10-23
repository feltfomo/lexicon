{
  lib,
  axiom,
  krisis,
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "lexicon";
  };
  reporter = krisis.effects.reporter { formatDiagnostic = krisis.renderPlain; };
  at =
    path: code: message:
    problem {
      inherit code message;
      primary.label = krisis.renderPath path;
    };
  field = path: name: validate: {
    required = true;
    inherit validate;
    onMissing = _: at (path ++ [ name ]) "required" "required field is missing";
    onInvalid = _: value: at (path ++ [ name ]) "shape" "unexpected ${builtins.typeOf value}";
  };
  locate =
    path: diagnostic:
    if diagnostic ? primary.label then
      diagnostic
    else
      diagnostic
      // {
        primary = (diagnostic.primary or { }) // {
          label = krisis.renderPath path;
        };
      };
  locateField =
    path: name: spec:
    if !builtins.isAttrs spec then
      spec
    else
      spec
      // lib.optionalAttrs (spec ? onInvalid && builtins.isFunction spec.onInvalid) {
        onInvalid = record: value: locate (path ++ [ name ]) (spec.onInvalid record value);
      }
      // lib.optionalAttrs (spec ? onMissing && builtins.isFunction spec.onMissing) {
        onMissing = record: locate (path ++ [ name ]) (spec.onMissing record);
      }
      // lib.optionalAttrs (spec ? parse && builtins.isFunction spec.parse) {
        parse = value: axiom.validation.mapDiagnostics (locate (path ++ [ name ])) (spec.parse value);
      };
  schema =
    path: fields:
    axiom.schema.compile {
      fields = if builtins.isAttrs fields then lib.mapAttrs (locateField path) fields else fields;
      onRecord = _: at path "record" "expected an attribute set";
      onUnknown = name: _: at (path ++ [ name ]) "unknown-field" "unregistered field ${name}";
    };
  registry =
    path: registrations:
    reporter.finish (
      axiom.registry.compile {
        inherit registrations;
        keyOf = registration: registration.name;
        less = _: _: false;
        onDuplicate = name: _: at path "duplicate-definition" "duplicate definition ${name}";
      }
    );
in
{
  inherit
    at
    field
    schema
    registry
    ;
  inherit (reporter) checked finish;
  nonempty = value: builtins.isString value && value != "";
}
