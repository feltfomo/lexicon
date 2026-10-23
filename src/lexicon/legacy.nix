{
  lib,
  axiom,
  krisis,
  claimKeys,
}:
{
  direct ? false,
}:
let
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  rename =
    mapping: entry:
    if !builtins.isAttrs entry then
      entry
    else
      let
        collisions = builtins.filter (key: entry ? ${key} && entry ? ${mapping.${key}}) (
          builtins.attrNames mapping
        );
        checked = report.checked (map (
          key: report.at [ key ] "legacy-mix" "legacy and canonical field spellings cannot be mixed"
        ) collisions) entry;
      in
      removeAttrs checked (builtins.attrNames mapping)
      // builtins.listToAttrs (
        map (key: {
          name = mapping.${key};
          value = checked.${key};
        }) (builtins.filter (key: checked ? ${key}) (builtins.attrNames mapping))
      );
  collection =
    f: value:
    if builtins.isFunction value then
      args:
      let
        result = value args;
      in
      if builtins.isList result then map f result else result
    else if builtins.isList value then
      map f value
    else
      value;
  directory =
    entry:
    rename {
      src = "source";
      dest = "destination";
    } entry;
  unit =
    raw:
    if direct then
      { value = raw; }
    else if !builtins.isAttrs raw then
      raw
    else
      let
        reserved = claimKeys ++ [
          "children"
          "value"
          "label"
          "source"
          "mergeProfile"
        ];
        annotations = builtins.intersectAttrs (lib.genAttrs reserved (_: null)) raw;
        body = removeAttrs raw reserved;
        checked = report.checked (lib.optional (raw ? value && body != { }) (
          report.at [ "nixos" ] "unit-mixed-value" "a unit cannot mix value with inline native config"
        )) raw;
      in
      builtins.seq checked (
        removeAttrs annotations [
          "children"
          "value"
        ]
        // lib.optionalAttrs (raw ? children) { children = collection unit raw.children; }
        // {
          value = checked.value or body;
        }
      );
  translate =
    raw:
    if !builtins.isAttrs raw then
      raw
    else
      let
        legacyFields = [
          "pkg"
          "files"
          "links"
          "directories"
          "imports"
        ];
        mixes =
          (raw ? package && raw ? pkg)
          || (
            raw ? furnish
            && builtins.any (name: raw ? ${name}) [
              "files"
              "links"
              "directories"
            ]
          );
        checked = report.checked (lib.optional mixes (
          report.at [ ] "legacy-mix" "legacy and canonical declaration forms cannot be mixed"
        )) raw;
        hm =
          if checked ? imports && checked.imports != [ ] then
            {
              homeManager =
                if checked ? homeManager && lib.isFunction checked.homeManager then
                  lib.setFunctionArgs (
                    args:
                    let
                      module = checked.homeManager args;
                    in
                    module // { imports = checked.imports ++ (module.imports or [ ]); }
                  ) (lib.functionArgs checked.homeManager)
                else if checked ? homeManager then
                  checked.homeManager // { imports = checked.imports ++ (checked.homeManager.imports or [ ]); }
                else
                  { inherit (checked) imports; };
            }
          else
            lib.optionalAttrs (checked ? homeManager) { inherit (checked) homeManager; };
        furnish =
          lib.optionalAttrs (checked ? files) {
            files = collection (rename {
              src = "source";
              dest = "destination";
            }) checked.files;
          }
          // lib.optionalAttrs (checked ? links) {
            links = collection (rename {
              target = "source";
              dest = "destination";
            }) checked.links;
          }
          // lib.optionalAttrs (checked ? directories) {
            directories = collection directory checked.directories;
          };
      in
      removeAttrs checked (
        legacyFields
        ++ [
          "nixos"
          "homeManager"
        ]
      )
      // lib.optionalAttrs (checked ? pkg) { package = checked.pkg; }
      // lib.optionalAttrs (furnish != { }) { inherit furnish; }
      // hm
      // lib.optionalAttrs (checked ? nixos) {
        nixos =
          if builtins.isFunction checked.nixos then
            args:
            let
              result = checked.nixos args;
            in
            map unit (if builtins.isList result then result else [ result ])
          else
            map unit (if builtins.isList checked.nixos then checked.nixos else [ checked.nixos ]);
      };
in
translate
