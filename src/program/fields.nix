{
  lib,
  axiom,
}:
let
  lifecycleKeys = [
    "representation"
    "onConflict"
    "provenance"
  ];

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

in
{
  inherit
    lifecycleKeys
    validRelativePath
    validBaseName
    validSubdir
    unknownFields
    joinSource
    ;

  lifecycleKeysAttrs = lib.genAttrs lifecycleKeys (_: null);
}
