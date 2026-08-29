# a declaration becomes ownership units here. each builder answers one question:
# which claim owns this entry, and what does the entry look like once its claim
# keys are stripped off. nothing in this file resolves or validates -- the
# schemas ran before it and the engine runs after it.
{
  lib,
  fields,
  themeUnits,
}:
let
  inherit (fields) claimsOf withoutClaims;

  entryUnit =
    fieldName: entry:
    claimsOf entry
    // {
      ${fieldName} = [ (withoutClaims entry) ];
    };

  # names are read before the rule schema has run, so anything malformed is
  # dropped rather than trusted; the schema reports it a moment later.
  safeRuleNames =
    rule:
    if builtins.isAttrs rule && rule ? names && builtins.isList rule.names then
      builtins.filter builtins.isString rule.names
    else
      [ ];

  # a directory's own claim owns both the directory entry and every per-name
  # override under it, so the overrides can narrow further but never escape the
  # directory that declared them.
  directoryUnit =
    index: directory:
    let
      rules =
        if builtins.isAttrs directory && directory ? files && builtins.isList directory.files then
          directory.files
        else
          [ ];
    in
    claimsOf directory
    // {
      children = [
        {
          directoryEntries = [
            {
              inherit index;
              entry = withoutClaims directory;
              reservedNames = builtins.concatMap safeRuleNames rules;
            }
          ];
        }
      ]
      ++ map (
        rule:
        claimsOf rule
        // {
          directoryFileRules = [
            {
              inherit index;
              entry = withoutClaims rule;
            }
          ];
        }
      ) rules;
    };

  furnishUnit =
    spec:
    claimsOf spec
    // {
      children =
        map (entryUnit "files") (spec.files or [ ])
        ++ lib.imap0 directoryUnit (spec.directories or [ ])
        ++ themeUnits spec;
    };

  specUnit =
    spec:
    let
      pkg = spec.pkg or null;
      imports = spec.imports or [ ];
    in
    claimsOf spec
    // {
      children =
        lib.optional (pkg != null) { inherit pkg; } ++ lib.optional (imports != [ ]) { inherit imports; };
    };
in
{
  inherit
    entryUnit
    safeRuleNames
    directoryUnit
    furnishUnit
    specUnit
    ;
}
