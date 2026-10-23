{
  lib,
  axiom,
  krisis,
  mkCoordinator,
  resources,
}:
{
  context,
  selected,
  filePrincipals,
  hostUserNames,
}:
let
  inherit (context) pkgs config user;
  hostName = config.networking.hostName;
  inherit (pkgs.stdenv.hostPlatform) system;
  namespace =
    if context.host != null && context.host ? id then context.host.id else "${system}/${hostName}";
  files = import ../furnish/files.nix {
    inherit lib;
    inherit (resources) contract;
  };
  composition = import ../program/theme/composition.nix { inherit lib axiom krisis; };
  principals = builtins.filter (principal: principal.authority.scope == "user") (filePrincipals {
    inherit system user;
    host = hostName;
  });
  groups = map (principal: {
    inherit principal;
    entries = map (
      entry:
      composition.lower pkgs (
        entry
        // {
          inherit principal;
          filesystemNamespace = namespace;
        }
      )
    ) selected.themeEntries;
  }) principals;
  tagged = builtins.concatMap (group: group.entries) groups;
in
{
  imports = [
    (import ../furnish/runtime.nix { inherit mkCoordinator krisis axiom; })
    (import ../program/theme/matugen-runtime.nix { inherit krisis axiom; })
    (import ../program/theme/composition-runtime.nix { inherit krisis axiom; })
    {
      assertions =
        lib.optional (selected.files != [ ] || selected.links != [ ] || selected.themeEntries != [ ])
          {
            assertion = config.lexicon.furnish.declarations != [ ];
            message = "furnish: file entries on ${hostName} reached no user principal (have: ${
              lib.concatStringsSep ", " (hostUserNames {
                inherit system;
                host = hostName;
              })
            })";
          };
      lexicon = {
        furnish.declarations = builtins.concatMap (
          group:
          files.mkDeclarations {
            filesystemNamespace = namespace;
            principals = [ group.principal ];
            files = selected.files ++ resources.theme.themeFiles group.entries pkgs;
            inherit (selected) links;
          }
        ) groups;
        theme = {
          matugen.entries = builtins.filter (entry: entry.runtime == "matugen") tagged;
          composition = {
            ordinary = builtins.filter (entry: entry.merge == null) tagged;
            entries = builtins.filter (entry: entry.merge != null) tagged;
          };
        };
      };
    }
  ];
}
