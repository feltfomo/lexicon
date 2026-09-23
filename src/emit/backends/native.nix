# the native placement passes each host to the module evaluator.
{ lib }:
{
  name = "native";

  needs = [
    "lexiconPackage"
    "systemEvaluator"
  ];

  # host is handed to the evaluator, so every module reads it the way it reads
  # the module system's own arguments
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

      # a host lexicon manages carries the binary that manages it, because
      # lexicon placed the host and not because a module listed it
      managed = {
        environment.systemPackages = [ (handed.lexiconPackage host.system) ];
      };

      modules = lib.concatMap (one: one.classes.nixos) projected ++ [ managed ];
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
