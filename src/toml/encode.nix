{
  lib,
  axiom,
  krisis,
}:
let
  inherit (axiom) validation;
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
    validation.failure [ (diagnostic path code message) ];
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
    validation.fromDiagnostics (validation.optional (!builtins.isString value) (
      diagnostic path "constructor-value" "${kind} requires a string"
    )) (node kind value);
  table =
    path: value:
    validation.map (node "table") (validation.traverseAttrs (key: encode (path ++ [ key ])) value);
  array =
    path: values:
    validation.map (node "array") (
      validation.sequence (lib.imap0 (index: encode (path ++ [ index ])) values)
    );
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
    inline = path: value: validation.map (node "inline") (tableValue path value);
    tables =
      path: value:
      if builtins.isList value then
        validation.map (values: node "tables" (node "array" values)) (
          validation.sequence (lib.imap0 (index: tableValue (path ++ [ index ])) value)
        )
      else
        reject path "tables-value" "tables requires a list of attribute sets";
  };

  types = {
    set =
      path: value:
      if isTagged value then
        validation.andThen (constructor: constructors.${constructor.kind} path constructor.value) (
          (constructorSchema path) value
        )
      else if lib.isDerivation value then
        validation.success (node "scalar" (toString value))
      else
        table path value;
    list = array;
    float = _: value: validation.success (node "float" (builtins.toJSON value));
    string = _: value: validation.success (node "scalar" value);
    bool = _: value: validation.success (node "scalar" value);
    int = _: value: validation.success (node "scalar" value);
    path = _: value: validation.success (node "scalar" (toString value));
  };
  encode =
    path: value:
    (types.${builtins.typeOf value}
    or (path: value: reject path "unsupported-value" "unsupported ${builtins.typeOf value}")
    )
      path
      value;
  document =
    value:
    validation.andThen (
      encoded:
      validation.fromDiagnostics (validation.optional (
        !(builtins.elem encoded.kind [
          "table"
          "document"
        ])
      ) (diagnostic [ ] "document-shape" "document must be attributes or a document constructor")) encoded
    ) (encode [ ] value);
in
{
  inherit isTagged document;
}
