# reads one collected run and renders its report. this is the only place the
# analysis touches the filesystem. it runs as its own impure evaluation over
# files the runner wrote, never inside a build, so reading them isn't
# import-from-derivation
{ lib, dir }:
let
  analysis = import ./. { inherit lib; };
  catalog = import ../workloads;

  run = builtins.fromJSON (builtins.readFile (dir + "/run.json"));

  json = path: if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else null;

  read =
    cellDir: name:
    let
      path = cellDir + "/${name}";
      output = path + "/output.json";
    in
    analysis.sample {
      inherit name;
      inherit (run) bench;
      meta = json (path + "/meta.json");
      stats = json (path + "/stats.json");
      projection = if builtins.pathExists output then builtins.hashFile "sha256" output else null;
    };

  # sample directories start with their schedule position, which orders them
  # numerically past nine samples too
  cell =
    cellDir:
    map (read cellDir) (
      builtins.sort (
        a: b: lib.toInt (lib.head (lib.splitString "-" a)) < lib.toInt (lib.head (lib.splitString "-" b))
      ) (builtins.attrNames (builtins.readDir cellDir))
    );

  cellsDir = dir + "/cells";
  cells =
    if builtins.pathExists cellsDir then
      builtins.mapAttrs (
        workload: _:
        builtins.mapAttrs (size: _: cell (cellsDir + "/${workload}/${size}")) (
          builtins.readDir (cellsDir + "/${workload}")
        )
      ) (builtins.readDir cellsDir)
    else
      { };
in
analysis.render (
  analysis.compare {
    inherit run cells;
    inherit (catalog) limits;
  }
)
