# the walk. conventional trees read whole, a settings file deciding what stays
# out, and a knot at the end so a file can name any other file's value
{
  lib,
  fx,
  krisis,
  arrows,
  vocabulary,
  types,
  construct,
}:
let
  inherit (vocabulary) emit;
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

  rootFiles =
    configuration: root:
    Presence.case {
      missing =
        absent:
        fx.bind (emit.unknown-walk-root {
          at = [ absent ];
          context = {
            root = absent;
          };
        }) (_: fx.pure [ ]);

      tree = present: fx.pure (filesUnder configuration present);
    } (presenceOf configuration root);

  discoverStage = pipeline.mkStage {
    name = "discover";
    transform =
      _:
      pipeline.bind pipeline.ask (
        env:
        pipeline.bind (arrows.traverse (rootFiles env.configuration) env.settings.roots) (
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
    exclusion:
    emit.excluded-path-missing {
      at = [
        "exclude"
        exclusion
      ];
      context = {
        path = exclusion;
      };
    };

  screenStage = pipeline.mkStage {
    name = "screen";
    transform =
      discovered:
      pipeline.bind (pipeline.asks (env: env.settings.exclude)) (
        exclusions:
        let
          idle = builtins.filter (exclusion: !builtins.any (covers exclusion) discovered) exclusions;

          screened = map (screen exclusions) discovered;

          surviving = builtins.concatMap (
            decision:
            Screening.case {
              kept = file: [ file ];
              dropped = _: [ ];
            } decision
          ) screened;
        in
        pipeline.bind (fx.seq (map idleExclusion idle)) (_: pipeline.pure surviving)
      );
  };

  # a name is read off the file list before anything is imported, and both
  # files are named
  resolveOne =
    name: group:
    if builtins.length group == 1 then
      Resolution.inject.unique {
        inherit name;
        inherit (builtins.head group) origin;
      }
    else
      Resolution.inject.clashing {
        inherit name;
        origins = map (file: file.origin) group;
      };

  collision =
    clash:
    emit.entry-name-collision {
      at = [ clash.name ];
      context = {
        inherit (clash) name;
        files = builtins.concatStringsSep " and " clash.origins;
      };
    };

  settle =
    decision:
    Resolution.case {
      unique = resolved: fx.pure [ resolved ];
      clashing = clash: fx.bind (collision clash) (_: fx.pure [ ]);
    } decision;

  resolveStage = pipeline.mkStage {
    name = "name-resolve";
    transform =
      screened:
      pipeline.bind (arrows.traverse settle (
        lib.mapAttrsToList resolveOne (lib.groupBy (file: file.name) screened)
      )) (settled: pipeline.pure (lib.concatLists settled));
  };

  # every value a file builds carries the file it came from, and the finished
  # set is handed back to each file so one can name another
  tie =
    configuration: resolved:
    lib.fix (
      self:
      lib.listToAttrs (
        map (
          entry:
          lib.nameValuePair entry.name (
            import (configuration + "/${entry.origin}") (
              (construct.from entry.origin)
              // {
                inherit lib fx;
                lexicon = self;
              }
            )
          )
        ) resolved
      )
    );

  tieStage = pipeline.mkStage {
    name = "tie";
    transform =
      resolved:
      pipeline.bind (pipeline.asks (env: env.configuration)) (
        configuration: pipeline.pure (tie configuration resolved)
      );
  };

  stages = [
    discoverStage
    screenStage
    resolveStage
    tieStage
  ];

  # the environment is installed for the walk only, so the krisis effects the
  # stages send rotate outward to whatever policy the caller opened
  walk =
    { configuration, settings }:
    krisis.gate (
      fx.effects.scope.run {
        handlers = fx.effects.reader.handler;
        state = {
          inherit configuration settings;
        };
      } (pipeline.compose stages null)
    );
in
{
  inherit walk;
}
