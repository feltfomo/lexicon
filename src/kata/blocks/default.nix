# the registry is data. a fifth block is one entry in this list plus its own
# file, and the layer that walks declarations never names one
{
  lib,
  fx,
  t,
  arrows,
  krisis,
  block,
  kinds,
  claimKeys,
  vocabulary,
}:
let
  # whether this registry holds a name, answered once for everything above
  Registration = arrows.sum {
    known = t.String;
    unregistered = t.String;
  };

  arguments = {
    inherit lib fx claimKeys;
    inherit (krisis) suggest;
    inherit (vocabulary.text) shown prose;
  };

  kindNames = map (kind: kind.name) kinds;

  # the registry is built over the entries it is handed, so a registration the
  # layer would never ship can still be read
  of =
    entries:
    let
      names = map (entry: entry.name) entries;

      byName = lib.listToAttrs (map (entry: lib.nameValuePair entry.name entry) entries);

      # legality is read off the block, so a new block reaches a kind without
      # that kind's registration changing
      allowedIn =
        name: map (entry: entry.name) (builtins.filter (entry: builtins.elem name entry.kinds) entries);

      sorted = lib.toposort (a: b: builtins.elem b.name a.before) entries;

      # a cycle leaves the declared list standing so the rest of the pass still
      # reports
      ordered = sorted.result or entries;

      cycleNames = map (entry: entry.name) (sorted.cycle or [ ]);

      cycleProblems = lib.optional (!(sorted ? result)) {
        code = "block-cycle";
        args = {
          at = lib.take 1 cycleNames ++ [ "before" ];
          context = {
            cycle = cycleNames;
          };
        };
      };

      problems = lib.concatMap (block.problemsOf kindNames names) entries ++ cycleProblems;

      emitters = lib.mapAttrs (_: block.vocabularyFor) byName;
    in
    {
      inherit
        names
        byName
        allowedIn
        ordered
        problems
        emitters
        ;

      has = name: byName ? ${name};

      classify =
        name:
        if byName ? ${name} then Registration.inject.known name else Registration.inject.unregistered name;

      order = map (entry: entry.name) ordered;
    };

  declared = map (entry: import entry arguments) [
    ./nixos.nix
    ./home-manager.nix
    ./furnish.nix
    ./theme.nix
  ];
in
of declared // { inherit of Registration; }
