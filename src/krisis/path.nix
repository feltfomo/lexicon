# copied unchanged out of the standalone krisis repo so paths already in
# people's terminals keep the same shape
{ lib }:
let
  renderPath =
    path:
    if !builtins.isList path then
      throw "krisis: validation path must be a list"
    else
      "$"
      + lib.concatMapStrings (
        part:
        if builtins.isString part then
          ".${lib.strings.escapeNixIdentifier part}"
        else if builtins.isInt part && part >= 0 then
          "[${toString part}]"
        else
          throw "krisis: validation path components must be strings or non-negative integers"
      ) path;
in
{
  inherit renderPath;
}
