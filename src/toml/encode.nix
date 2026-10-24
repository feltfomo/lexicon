{
  lib,
  axiom,
  krisis,
}:
let
  inherit (krisis) effects;
  inherit (effects.native) validation;
  mapChecked = f: validation.andThen (value: effects.accept (f value));
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "toml";
  };
  diagnostic =
    path: code: message:
    problem {
      inherit code message;
      primary.label = krisis.renderPath path;
    };
  reject =
    path: code: message:
    effects.fromDiagnostics [ (diagnostic path code message) ] null;
  isTagged = value: builtins.isAttrs value && builtins.isFunction (value.__lexiconToml or null);
  isTable = value: builtins.isAttrs value && !isTagged value && !lib.isDerivation value;
  node = kind: value: { inherit kind value; };

  constructorSchema =
    path:
    axiom.schema.compile {
      onRecord = _: diagnostic path "constructor" "constructor must be an attribute set";
      onUnknown =
        name: _: diagnostic (path ++ [ name ]) "constructor-field" "unknown constructor field ${name}";
      fields = {
        __lexiconToml = { };
        kind = {
          required = true;
          validate = value: builtins.isString value && builtins.hasAttr value constructors;
          onMissing = _: diagnostic path "constructor-kind" "constructor kind is required";
          onInvalid = _: _: diagnostic path "constructor-kind" "unknown constructor kind";
        };
        value = {
          required = true;
          onMissing = _: diagnostic path "constructor-value" "constructor value is required";
        };
      };
    };

  text =
    kind: path: value:
    effects.fromDiagnostics (lib.optional (!builtins.isString value) (
      diagnostic path "constructor-value" "${kind} requires a string"
    )) (node kind value);
  table =
    path: value:
    mapChecked (entries: node "table" (builtins.listToAttrs entries)) (
      validation.all (
        map (
          key:
          mapChecked (value: {
            name = key;
            inherit value;
          }) (encode (path ++ [ key ]) value.${key})
        ) (builtins.attrNames value)
      )
    );
  array =
    path: values:
    mapChecked (node "array") (validation.all (lib.imap0 (index: encode (path ++ [ index ])) values));
  tableValue =
    path: value:
    if isTable value then
      table path value
    else
      reject path "table-value" "requires attributes without a constructor or derivation";

  constructors = {
    literal = text "literal";
    document =
      path: value:
      if path == [ ] then
        text "document" path value
      else
        reject path "document-placement" "document is only valid as the whole input";
    inline = path: value: mapChecked (node "inline") (tableValue path value);
    tables =
      path: value:
      if builtins.isList value then
        mapChecked (values: node "tables" (node "array" values)) (
          validation.all (lib.imap0 (index: tableValue (path ++ [ index ])) value)
        )
      else
        reject path "tables-value" "tables requires a list of attribute sets";
  };

  types = {
    set =
      path: value:
      if isTagged value then
        validation.andThen (constructor: constructors.${constructor.kind} path constructor.value) (
          effects.fromAxiom ((constructorSchema path) value)
        )
      else if lib.isDerivation value then
        effects.accept (node "scalar" (toString value))
      else
        table path value;
    list = array;
    float = _: value: effects.accept (node "float" (builtins.toJSON value));
    string = _: value: effects.accept (node "scalar" value);
    bool = _: value: effects.accept (node "scalar" value);
    int = _: value: effects.accept (node "scalar" value);
    path = _: value: effects.accept (node "scalar" (toString value));
  };
  encode =
    path: value:
    (types.${builtins.typeOf value}
    or (path: value: reject path "unsupported-value" "unsupported ${builtins.typeOf value}")
    )
      path
      value;
  compile =
    value:
    validation.andThen (
      encoded:
      effects.fromDiagnostics (lib.optional (
        !(builtins.elem encoded.kind [
          "table"
          "document"
        ])
      ) (diagnostic [ ] "document-shape" "document must be attributes or a document constructor")) encoded
    ) (encode [ ] value);
in
{
  inherit isTagged compile;
  document = value: effects.resultOf (compile value);
}
