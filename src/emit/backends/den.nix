# the den placement applies each entity to its module before evaluation.
#
# den v0.18.0 rev 5df0987, read 2026-09-21, nix/lib/aspects/fx/wrap-classes.nix,
# bound an entity by stripping the names it applied off a module's arguments.
{ lib }:
{
  name = "den";

  needs = [
    "lexiconPackage"
    "systemEvaluator"
  ];

  supplies = [ ];

  # den v0.18.0 rev 5df0987, read 2026-09-21, modules/config.nix, defaulted
  # classModuleCollisionPolicy to error on a flat-form argument den also binds.
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

      # a host lexicon manages carries the binary that manages it, because
      # lexicon placed the host and not because a module listed it
      managed = {
        environment.systemPackages = [ (handed.lexiconPackage host.system) ];
      };

      # the binding comes last, so the module list still opens with the
      # first interior of the first entry
      modules = lib.concatMap (one: one.classes.nixos) projected ++ [ managed ] ++ bindings bound;
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
