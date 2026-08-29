# the vocabulary a program declaration is checked against. claim projection,
# relative-path shapes, and the labeled-diagnostic constructors sit here because
# the spec schemas, the directory walk, the unit builders, and the theme
# compiler all need the same answers and none of them owns the definition.
{
  lib,
  axiom,
  claimKeys,
  problem,
}:
let
  claimKeysAttrs = lib.genAttrs claimKeys (_: null);

  # the three keys furnish reads off any entry to decide how a file is written
  # and who wins when two aspects reach the same destination. they ride files,
  # directories, and per-name overrides identically, so they are named once.
  lifecycleKeys = [
    "representation"
    "onConflict"
    "provenance"
  ];

  claimsOf =
    value: if builtins.isAttrs value then builtins.intersectAttrs claimKeysAttrs value else { };

  withoutClaims = value: if builtins.isAttrs value then removeAttrs value claimKeys else value;

  validRelativePath =
    value:
    builtins.isString value
    && value != ""
    && !lib.hasPrefix "/" value
    && builtins.all (part: part != "" && part != "." && part != "..") (lib.splitString "/" value);

  validBaseName = value: validRelativePath value && builtins.length (lib.splitString "/" value) == 1;

  validSubdir =
    value: builtins.isString value && (value == "" || validRelativePath (lib.removeSuffix "/" value));

  unknownFields =
    allowed: value:
    if !builtins.isAttrs value then
      [ ]
    else
      builtins.filter (name: !(builtins.elem name allowed)) (builtins.attrNames value);

  # a flake source root is a path, a configured root is a string, and joining
  # them differs. keeping both here means callers never branch on it.
  joinSource =
    root: relative:
    if relative == "" then
      root
    else if builtins.isPath root then
      root + "/${relative}"
    else
      axiom.canonical.path [
        (lib.removeSuffix "/" root)
        relative
      ];

  labeled =
    subject: code: message:
    problem {
      inherit code message;
      primary.label = subject;
    };

  requiredLabeled = subject: code: message: predicate: {
    required = true;
    validate = predicate;
    onMissing = _entry: labeled subject code message;
    onInvalid = _entry: _value: labeled subject code message;
  };

  optionalLabeled = subject: code: message: predicate: {
    validate = predicate;
    onInvalid = _entry: _value: labeled subject code message;
  };

  nonEmptyString = value: builtins.isString value && value != "";
in
{
  inherit
    claimKeysAttrs
    lifecycleKeys
    claimsOf
    withoutClaims
    validRelativePath
    validBaseName
    validSubdir
    unknownFields
    joinSource
    labeled
    requiredLabeled
    optionalLabeled
    nonEmptyString
    ;

  lifecycleKeysAttrs = lib.genAttrs lifecycleKeys (_: null);
}
