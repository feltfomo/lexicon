# the native placement. the entity reaches a module as an evaluator argument
#
# the attribute that evaluates a system is published on the flake output of
# the tree that defines the module system and is absent from the lib a caller
# imports out of that tree, so it arrives as a capability. read 2026-09-21
{ lib }:
{
  name = "native";

  needs = [ "systemEvaluator" ];

  # handed to the evaluator, so every module reads it the way it reads the
  # module system's own arguments
  supplies = [ "host" ];

  binds = [ ];

  context = [
    "config"
    "options"
    "lib"
    "pkgs"
    "host"
  ];

  classes = [ "nixos" ];

  # every placement is handed the same arguments, and this one binds nothing,
  # so it takes no binder
  emit =
    {
      handed,
      host,
      entries,
      project,
      ...
    }:
    let
      projected = map (
        entry:
        {
          inherit (entry) name;
        }
        // project {
          bound = { };
          inherit (entry) interiors;
        }
      ) entries;

      modules = lib.concatMap (one: one.classes.nixos) projected;
    in
    {
      inherit host modules;

      carried = lib.listToAttrs (map (one: lib.nameValuePair one.name one.carried) projected);

      built = handed.systemEvaluator {
        inherit (host) system;
        inherit modules;
        specialArgs = {
          inherit host;
        };
      };
    };
}
