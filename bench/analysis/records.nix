# reads one collected run into the analysis's comparison input. this and the
# marker discovery it calls are the only places the analysis touches the
# filesystem. it runs as its own impure evaluation over files the runner wrote
# and over both sides' snapshots, never inside a build, so reading them isn't
# import-from-derivation
{ lib, dir }:
let
  analysis = import ./. { inherit lib; };
  catalog = import ../workloads;

  run = builtins.fromJSON (builtins.readFile (dir + "/run.json"));

  # each side's markers come from its own snapshot, so a marker moved or added by
  # the candidate is located where the candidate defines it
  markers = {
    baseline = analysis.discover run.baseline.source;
    candidate = analysis.discover run.candidate.source;
  };

  json = path: if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else null;

  read =
    workload: size: cellDir: name:
    let
      path = cellDir + "/${name}";
      output = path + "/output.json";
      order = lib.toInt (lib.head (lib.splitString "-" name));
      step =
        if order < builtins.length run.schedule then
          builtins.elemAt run.schedule order
        else
          {
            phase = "outside schedule";
            side = "candidate";
          };
    in
    analysis.sample {
      inherit name markers;
      inherit (run) bench;
      expected = {
        inherit workload order;
        inherit (step) side phase;
        inherit (run) evaluator;
        size = lib.toInt size;
        source = run.${step.side}.source;
      };
      meta = json (path + "/meta.json");
      stats = json (path + "/stats.json");
      profile = json (path + "/profile.json");
      projection = if builtins.pathExists output then builtins.hashFile "sha256" output else null;
    };

  # sample directories start with their schedule position, which orders them
  # numerically past nine samples too
  cell =
    workload: size: cellDir:
    map (read workload size cellDir) (
      builtins.sort (
        a: b: lib.toInt (lib.head (lib.splitString "-" a)) < lib.toInt (lib.head (lib.splitString "-" b))
      ) (builtins.attrNames (builtins.readDir cellDir))
    );

  cellsDir = dir + "/cells";
  cells =
    if builtins.pathExists cellsDir then
      builtins.mapAttrs (
        workload: _:
        builtins.mapAttrs (size: _: cell workload size (cellsDir + "/${workload}/${size}")) (
          builtins.readDir (cellsDir + "/${workload}")
        )
      ) (builtins.readDir cellsDir)
    else
      { };
in
{
  inherit run cells markers;
  inherit (catalog) limits;
}
