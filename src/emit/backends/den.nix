# the aspect placement. the entity is applied to the module before the module
# system sees it
#
# the aspect system binds an entity by reading a module's advertised argument
# names and stripping the ones it applies. den v0.18.0, rev 5df0987, read
# 2026-09-21, nix/lib/aspects/fx/wrap-classes.nix
#
# den.config.classModuleCollisionPolicy is error by default and fires on a
# name that is both a den entity argument and a module-system argument in a
# flat-form class module, so the bound names are struck off the advertised
# set. den v0.18.0, rev 5df0987, read 2026-09-21, modules/config.nix
{ lib }:
{
  name = "den";

  needs = [ "systemEvaluator" ];

  supplies = [ ];

  binds = [ "host" ];

  context = [
    "config"
    "options"
    "lib"
    "pkgs"
    "host"
  ];

  # the home class is placed against a user and this tree places hosts
  classes = [ "nixos" ];

  emit =
    {
      handed,
      host,
      entries,
      project,
      bindings,
    }:
    let
      bound = {
        inherit host;
      };

      projected = map (
        entry:
        {
          inherit (entry) name;
        }
        // project {
          inherit bound;
          inherit (entry) interiors;
        }
      ) entries;

      # the binding comes last, so the module list still opens with the
      # first interior of the first entry
      modules = lib.concatMap (one: one.classes.nixos) projected ++ bindings bound;
    in
    {
      inherit host modules;

      carried = lib.listToAttrs (map (one: lib.nameValuePair one.name one.carried) projected);

      built = handed.systemEvaluator {
        inherit (host) system;
        inherit modules;
        specialArgs = { };
      };
    };
}
