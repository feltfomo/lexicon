{
  pkgs,
  lib ? pkgs.lib,
}:
let
  python =
    assert lib.assertMsg (lib.versionAtLeast pkgs.python3Packages.tomlkit.version "0.15.0")
      "toml: TOML Kit >= 0.15.0 is required";
    pkgs.python3.withPackages (p: [ p.tomlkit ]);
  package = pkgs.writeShellApplication {
    name = "lexicon-toml";
    text = ''exec ${python}/bin/python ${./runtime.py} "$@"'';
  };
  tagged = kind: value: {
    __lexiconToml = x: x;
    inherit kind value;
  };
  isTagged = value: builtins.isAttrs value && builtins.isFunction (value.__lexiconToml or null);
  encode =
    path: value:
    if isTagged value then
      if
        builtins.attrNames value != [
          "__lexiconToml"
          "kind"
          "value"
        ]
      then
        throw "toml: invalid constructor at ${path}"
      else if
        builtins.elem value.kind [
          "literal"
          "document"
        ]
        && builtins.isString value.value
      then
        { inherit (value) kind value; }
      else if
        builtins.elem value.kind [
          "inline"
          "tables"
        ]
      then
        {
          inherit (value) kind;
          value = encode path value.value;
        }
      else
        throw "toml: invalid constructor at ${path}"
    else if builtins.isAttrs value && !lib.isDerivation value then
      {
        kind = "table";
        value = lib.mapAttrs (key: encode "${path}.${key}") value;
      }
    else if builtins.isList value then
      {
        kind = "array";
        value = lib.imap0 (i: encode "${path}[${toString i}]") value;
      }
    else if builtins.isFloat value then
      {
        kind = "float";
        value = builtins.toJSON value;
      }
    else if builtins.isString value || builtins.isBool value || builtins.isInt value then
      {
        kind = "scalar";
        inherit value;
      }
    else if builtins.isPath value || lib.isDerivation value then
      {
        kind = "scalar";
        value = toString value;
      }
    else
      throw "toml: unsupported ${builtins.typeOf value} at ${path}";
  generate =
    name: attrs:
    let
      input = pkgs.writeText "${name}.json" (builtins.toJSON (encode "$" attrs));
    in
    pkgs.runCommand name { } ''${package}/bin/lexicon-toml generate ${input} "$out"'';
  source =
    name: value:
    if isTagged value && value.kind == "document" then
      generate name value
    else if builtins.isAttrs value && !lib.isDerivation value then
      generate name value
    else if builtins.isPath value || builtins.isString value || lib.isDerivation value then
      value
    else
      throw "toml: source ${name} must be attributes, a document, a path or a file derivation";
  merge =
    name:
    {
      sources,
      conflict ? "error",
      arrays ? "replace",
    }:
    assert lib.assertMsg (
      builtins.isList sources && sources != [ ]
    ) "toml: merge requires a nonempty sources list";
    assert lib.assertMsg (builtins.elem conflict [
      "error"
      "first"
      "last"
    ]) "toml: conflict must be error, first or last";
    assert lib.assertMsg (arrays == "replace") "toml: arrays must be replace";
    let
      files = lib.imap0 (i: source "${name}-${toString i}") sources;
    in
    pkgs.runCommand name { } ''
      ${package}/bin/lexicon-toml merge --conflict ${conflict} "$out" ${lib.escapeShellArgs (map toString files)}
    '';
in
{
  inherit
    package
    generate
    merge
    source
    ;
  literal = tagged "literal";
  document = tagged "document";
  inline = tagged "inline";
  tables = tagged "tables";
}
