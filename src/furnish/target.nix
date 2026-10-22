{ lib }:
let
  externalPath =
    value:
    builtins.isString value
    && !builtins.hasContext value
    && lib.hasPrefix "/" value
    && value != "/"
    && builtins.all (part: part != "" && part != "." && part != "..") (
      lib.splitString "/" (lib.removePrefix "/" value)
    );
  valid =
    target:
    builtins.isAttrs target
    &&
      builtins.attrNames target == [
        "kind"
        "path"
      ]
    && (
      if target.kind == "external" then
        externalPath target.path
      else
        target.kind == "retained"
        && (builtins.isString target.path || builtins.isPath target.path || lib.isDerivation target.path)
    );
in
{
  inherit externalPath valid;
  normalize = target: target // { path = toString target.path; };
  materialize =
    declaration:
    if declaration.source.kind == "external" then
      {
        kind = "external";
        path = declaration.source.value;
      }
    else if declaration.source.kind == "path" then
      {
        kind = "retained";
        path = builtins.path {
          path = declaration.source.value;
          name = "furnish-${baseNameOf declaration.filesystemIdentity.destination}";
        };
      }
    else
      throw "furnish: unsupported source kind ${declaration.source.kind}";
}
