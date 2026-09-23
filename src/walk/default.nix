# the walk. conventional trees read whole, a settings file deciding what
# stays out, and a knot at the end so a file can name any other file's value
#
# the roots come from more than one subsystem and the knot is still one, so a
# file under one subsystem's tree names an entry another subsystem's tree
# declared. what each subsystem owns is read back off the roots afterwards
{
  lib,
  fx,
  krisis,
  arrows,
  t,
}:
let
  types = import ./types.nix { inherit lib fx t; };

  vocabulary = import ./vocabulary.nix;

  inherit (arrows) sum;
  inherit (fx) pipeline;

  Presence = sum {
    missing = types.Relative;
    tree = types.Relative;
  };

  Screening = sum {
    kept = types.Screened;
    dropped = types.Discovered;
  };

  Resolution = sum {
    unique = types.Resolved;
    clashing = types.Clash;
  };

  # readDir and import are the whole of the walk's contact with disk. every
  # stage past the file list runs on the substrate
  beneath =
    directory: relative:
    let
      here = if relative == "" then directory else directory + "/${relative}";
      under = name: if relative == "" then name else "${relative}/${name}";
    in
    lib.concatLists (
      lib.mapAttrsToList (
        name: node:
        if node == "directory" then
          beneath directory (under name)
        else if lib.hasSuffix ".nix" name then
          [ (under name) ]
        else
          [ ]
      ) (builtins.readDir here)
    );

  presenceOf =
    configuration: root:
    if builtins.pathExists (configuration + "/${root}") then
      Presence.inject.tree root
    else
      Presence.inject.missing root;

  filesUnder =
    configuration: root:
    map (relative: {
      inherit root relative;
      origin = "${root}/${relative}";
    }) (beneath (configuration + "/${root}") "");

  # a root nobody put on disk is named in the words of the subsystem whose
  # settings file asked for it
  rootFiles =
    configuration: subsystem: root:
    Presence.case {
      missing =
        absent:
        fx.bind (subsystem.emit.unknown-walk-root {
          at = [ absent ];
          context = {
            root = absent;
          };
        }) (_: fx.pure [ ]);

      tree = present: fx.pure (filesUnder configuration present);
    } (presenceOf configuration root);

  discoveredFor =
    configuration: subsystem:
    fx.map lib.concatLists (arrows.traverse (rootFiles configuration subsystem) subsystem.roots);

  discoverStage = pipeline.mkStage {
    name = "discover";
    outputType = t.listOf types.Discovered;
    transform =
      _:
      pipeline.bind pipeline.ask (
        env:
        pipeline.bind (arrows.traverse (discoveredFor env.configuration) env.subsystems) (
          found: pipeline.pure (lib.concatLists found)
        )
      );
  };

  covers = exclusion: file: file.relative == exclusion || lib.hasPrefix "${exclusion}/" file.relative;

  screen =
    exclusions: file:
    if builtins.any (exclusion: covers exclusion file) exclusions then
      Screening.inject.dropped file
    else
      Screening.inject.kept (
        file
        // {
          name = lib.removeSuffix ".nix" (baseNameOf file.relative);
        }
      );

  idleExclusion =
    subsystem: exclusion:
    subsystem.emit.excluded-path-missing {
      at = [
        "exclude"
        exclusion
      ];
      context = {
        path = exclusion;
      };
    };

  # a subsystem screens the files its own roots offered against its own
  # exclusions, so an exclusion is answered by the trees it was written for
  screenedFor =
    subsystem: discovered:
    let
      offered = builtins.filter (file: builtins.elem file.root subsystem.roots) discovered;

      idle = builtins.filter (exclusion: !builtins.any (covers exclusion) offered) subsystem.exclude;

      surviving = builtins.concatMap (
        decision:
        Screening.case {
          kept = file: [ file ];
          dropped = _: [ ];
        } decision
      ) (map (screen subsystem.exclude) offered);
    in
    fx.bind (fx.seq (map (idleExclusion subsystem) idle)) (_: fx.pure surviving);

  screenStage = pipeline.mkStage {
    name = "screen";
    inputType = t.listOf types.Discovered;
    outputType = t.listOf types.Screened;
    transform =
      discovered:
      pipeline.bind (pipeline.asks (env: env.subsystems)) (
        subsystems:
        pipeline.bind (arrows.traverse (subsystem: screenedFor subsystem discovered) subsystems) (
          kept: pipeline.pure (lib.concatLists kept)
        )
      );
  };

  # a name is read off the file list before anything is imported, and both
  # files are named. the group spans every root, so two trees landing on one
  # name is refused the way two files in one tree are
  resolveOne =
    name: group:
    if builtins.length group == 1 then
      Resolution.inject.unique {
        inherit name;
        inherit (builtins.head group) origin root;
      }
    else
      Resolution.inject.clashing {
        inherit name;
        inherit (builtins.head group) root;
        origins = map (file: file.origin) group;
      };

  # the origins carry the root each file was offered from, so a reader sees
  # both trees however the group was split
  collision =
    owner: clash:
    (owner clash.root).emit.entry-name-collision {
      at = [ clash.name ];
      context = {
        inherit (clash) name;
        files = builtins.concatStringsSep " and " clash.origins;
      };
    };

  settle =
    owner: decision:
    Resolution.case {
      unique = resolved: fx.pure [ resolved ];
      clashing = clash: fx.bind (collision owner clash) (_: fx.pure [ ]);
    } decision;

  resolveStage = pipeline.mkStage {
    name = "name-resolve";
    inputType = t.listOf types.Screened;
    outputType = t.listOf types.Resolved;
    transform =
      screened:
      pipeline.bind (pipeline.asks (env: ownerOf env.subsystems)) (
        owner:
        pipeline.bind (arrows.traverse (settle owner) (
          lib.mapAttrsToList resolveOne (lib.groupBy (file: file.name) screened)
        )) (settled: pipeline.pure (lib.concatLists settled))
      );
  };

  # every value a file builds carries the file it came from, and the finished
  # set is handed back to each file so one can name another. the constructors
  # a file is handed are the ones of the subsystem whose root offered it
  tie =
    configuration: owner: resolved:
    lib.fix (
      self:
      lib.listToAttrs (
        map (
          entry:
          lib.nameValuePair entry.name (
            import (configuration + "/${entry.origin}") (
              (owner entry.root).constructorsFor entry.origin
              // {
                inherit lib fx;
                lexicon = self;
              }
            )
          )
        ) resolved
      )
    );

  # the partition is read back off the roots the walk was handed, so nothing
  # downstream asks a value which subsystem built it
  ownedBy =
    subsystems: resolved: entries:
    lib.listToAttrs (
      map (
        subsystem:
        lib.nameValuePair subsystem.name (
          lib.getAttrs (map (entry: entry.name) (
            builtins.filter (entry: builtins.elem entry.root subsystem.roots) resolved
          )) entries
        )
      ) subsystems
    );

  # what leaves here is the tied set beside the partition read back off the
  # roots, a pair no shape in types.nix describes, so there is nothing
  # truthful to check it against
  tieStage = pipeline.mkStage {
    name = "tie";
    inputType = t.listOf types.Resolved;
    transform =
      resolved:
      pipeline.bind pipeline.ask (
        env:
        let
          entries = tie env.configuration (ownerOf env.subsystems) resolved;
        in
        pipeline.pure {
          inherit entries;
          owned = ownedBy env.subsystems resolved entries;
        }
      );
  };

  ownerOf =
    subsystems:
    let
      byRoot = lib.listToAttrs (
        lib.concatMap (subsystem: map (root: lib.nameValuePair root subsystem) subsystem.roots) subsystems
      );
    in
    root: byRoot.${root};

  stages = [
    discoverStage
    screenStage
    resolveStage
    tieStage
  ];

  # the environment is installed for the walk only, so the krisis effects the
  # stages send rotate outward to whatever policy the caller opened
  run =
    { configuration, subsystems }:
    krisis.gate (
      fx.effects.scope.run {
        handlers = fx.effects.reader.handler;
        state = {
          inherit configuration subsystems;
        };
      } (pipeline.compose stages null)
    );
in
{
  inherit run types;
  inherit (vocabulary) codes;
}
