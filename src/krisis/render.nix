# the emitter hands over the value, the interpreter decides how much of it
# gets printed. a value that throws when forced costs the fallback string
{ lib, fx }:
let
  effect = "krisis/render";

  scalarTypes = [
    "bool"
    "float"
    "int"
    "null"
    "path"
    "string"
  ];

  fail = message: throw "krisis: ${message}";

  bound =
    name: value:
    if builtins.isInt value && value >= 0 then
      value
    else
      fail "render option '${name}' must be a non-negative integer; got ${builtins.typeOf value}";

  text =
    name: value:
    if builtins.isString value then
      value
    else
      fail "render option '${name}' must be a string; got ${builtins.typeOf value}";

  isDerivation =
    value:
    if !builtins.isAttrs value || !(value ? type) then
      false
    else
      let
        attempted = builtins.tryEval value.type;
      in
      attempted.success && builtins.isString attempted.value && attempted.value == "derivation";

  derivationName =
    value:
    let
      attempted = if value ? name then builtins.tryEval value.name else { success = false; };
    in
    if attempted.success && builtins.isString attempted.value then attempted.value else "?";

  truncate =
    limit: value:
    if builtins.stringLength value <= limit then value else "${builtins.substring 0 limit value}…";

  normalizeScalar =
    maxStringLength: value:
    if builtins.isPath value then
      truncate maxStringLength (builtins.unsafeDiscardStringContext (toString value))
    else if builtins.isString value then
      truncate maxStringLength value
    else
      value;

  renderScalar =
    maxStringLength: value:
    if builtins.elem (builtins.typeOf value) scalarTypes then
      builtins.toJSON (normalizeScalar maxStringLength value)
    else
      null;

  renderList =
    config: values:
    let
      shown = lib.take config.maxListItems values;
      omitted = builtins.length values - builtins.length shown;
    in
    if builtins.all (value: builtins.elem (builtins.typeOf value) scalarTypes) shown then
      builtins.toJSON (map (normalizeScalar config.maxStringLength) shown)
      + lib.optionalString (omitted > 0) " (+${toString omitted} more)"
    else
      config.fallback;

  renderShape =
    config: value:
    let
      names = builtins.attrNames value;
      shown = lib.take config.maxAttrs names;
      omitted = builtins.length names - builtins.length shown;
    in
    "{ ${lib.concatStringsSep ", " shown}${
      lib.optionalString (omitted > 0) ", … (+${toString omitted})"
    } }";

  attempt =
    fallback: rendered:
    let
      result = builtins.tryEval rendered;
    in
    if result.success && result.value != null then result.value else fallback;

  renderWith =
    config: value:
    attempt config.fallback (
      if isDerivation value then
        "<derivation ${truncate config.maxStringLength (derivationName value)}>"
      else if builtins.isFunction value then
        "<function>"
      else if builtins.isAttrs value then
        (if config.attrsets == "shape" then renderShape config value else config.fallback)
      else if builtins.isList value then
        renderList config value
      else
        renderScalar config.maxStringLength value
    );

  known = [
    "maxStringLength"
    "maxListItems"
    "maxAttrs"
    "attrsets"
    "fallback"
  ];

  bounded =
    options:
    let
      unknown = builtins.filter (name: !builtins.elem name known) (builtins.attrNames options);

      attrsets = text "attrsets" (options.attrsets or "unrenderable");

      config = {
        maxStringLength = bound "maxStringLength" (options.maxStringLength or 256);
        maxListItems = bound "maxListItems" (options.maxListItems or 32);
        maxAttrs = bound "maxAttrs" (options.maxAttrs or 32);
        fallback = text "fallback" (options.fallback or "<unrenderable value>");
        attrsets =
          if
            builtins.elem attrsets [
              "shape"
              "unrenderable"
            ]
          then
            attrsets
          else
            fail "render option 'attrsets' must be \"shape\" or \"unrenderable\"";
      };
    in
    if unknown != [ ] then
      fail "unknown render option '${builtins.head unknown}'"
    else
      # forced here, or a bad budget comes back as a fallback string on every
      # value instead of an error where it was written
      builtins.deepSeq config {
        ${effect} =
          { param, state }:
          {
            resume = renderWith config param;
            inherit state;
          };
      };
in
{
  inherit effect bounded;

  show = value: fx.send effect value;

  default = bounded { };

  # for callers who don't want attribute names reaching a log
  strict = bounded {
    maxStringLength = 64;
    maxListItems = 8;
    attrsets = "unrenderable";
  };
}
