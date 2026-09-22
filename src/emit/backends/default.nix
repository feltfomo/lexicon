# what every placement this tree ships may advertise, checked here
{
  lib,
  krisis,
  types,
}:
let
  # the names an evaluator injects into every module it reads. measured
  # 2026-09-21
  supplied = [
    "config"
    "options"
    "lib"
    "pkgs"
    "modulesPath"
  ];

  problemsOf =
    backend:
    let
      reachable = supplied ++ backend.supplies ++ backend.binds;

      wanted = types.ContextName reachable;
    in
    map (
      argument:
      let
        nearest = krisis.suggest argument reachable;
      in
      {
        code = "unsupplyable-context-argument";
        args = {
          at = [
            backend.name
            "context"
            argument
          ];
          context = {
            backend = backend.name;
            inherit argument;
          };
          notes = lib.optional (nearest != null) "did you mean '${nearest}'?";
        };
      }
    ) (builtins.filter (name: !wanted.check name) backend.context);

  of =
    entries:
    let
      byName = lib.listToAttrs (map (entry: lib.nameValuePair entry.name entry) entries);
    in
    {
      inherit entries byName supplied;

      names = map (entry: entry.name) entries;

      problems = lib.concatMap problemsOf entries;

      has = name: byName ? ${name};
    };

  declared = map (entry: import entry { inherit lib; }) [
    ./native.nix
    ./den.nix
  ];
in
of declared // { inherit of; }
