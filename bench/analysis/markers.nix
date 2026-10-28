# benchmark markers of one revision and what samples say about them. a marker is
# located by name with unsafeGetAttrPos against that revision's own markers.nix,
# so no line number is ever stored and either side can move its markers freely
{ lib }:
let
  # trees that hold no owner's code. a fixture named markers.nix under tests
  # would otherwise become a region
  skipped = [
    "verification"
    "examples"
    "tests"
    "bench"
    "docs"
  ];

  keep =
    name: kind:
    kind == "directory"
    && !(builtins.elem name skipped)
    && !(lib.hasPrefix "." name)
    && builtins.match "result(-.*)?" name == null;

  # every owner directory holding a markers.nix, relative to the root. only
  # directories are read, never a file other than markers.nix itself
  owners =
    root:
    let
      walk =
        relative:
        let
          entries = builtins.readDir (if relative == "" then root else root + "/${relative}");
          here = lib.optional ((entries."markers.nix" or null) == "regular") relative;
          below = lib.concatMap (name: walk (if relative == "" then name else "${relative}/${name}")) (
            builtins.attrNames (lib.filterAttrs keep entries)
          );
        in
        here ++ below;
    in
    walk "";

  # a region is the owner's path and the attribute, as in src/ownerships.resolveContext
  discover =
    root:
    let
      base = if builtins.isPath root then root else /. + root;
    in
    lib.concatMap (
      owner:
      let
        defined = import (base + "/${owner}/markers.nix");
      in
      map (
        name:
        let
          position = builtins.unsafeGetAttrPos name defined;
        in
        {
          inherit owner name;
          region = "${owner}.${name}";
          inherit (position) file line;
        }
      ) (builtins.attrNames defined)
    ) (owners base);

  key = file: line: "${file}:${toString line}";

  # call counts are keyed by the lambda's definition, and each marker is the only
  # lambda on its line, so file and line name it without a column
  entries =
    markers: stats:
    let
      byPosition = builtins.listToAttrs (
        map (marker: {
          name = key marker.file marker.line;
          value = marker.region;
        }) markers
      );
      counted = builtins.foldl' (
        totals: entry:
        let
          region = byPosition.${key (entry.file or "") (entry.line or 0)} or null;
        in
        if region == null then totals else totals // { ${region} = (totals.${region} or 0) + entry.count; }
      ) { } stats.functions;
    in
    lib.genAttrs (map (marker: marker.region) markers) (region: counted.${region} or 0);

  # a profiler frame prints the call site and the lambda's name, not its
  # definition. a marker's frames are only attributable when no other applied
  # lambda shares its name, which the same expression's call counts show
  ambiguous =
    markers: stats:
    let
      positions = builtins.listToAttrs (
        map (marker: {
          name = key marker.file marker.line;
          value = true;
        }) markers
      );
      defined = map (marker: marker.name) markers;
      names = lib.genAttrs defined (_: true);
      others = builtins.filter (
        entry:
        entry.name or null != null
        && names ? ${entry.name}
        && !(positions ? ${key (entry.file or "") (entry.line or 0)})
      ) stats.functions;
      shared = builtins.filter (name: lib.count (other: other == name) defined > 1) defined;
    in
    lib.unique (shared ++ map (entry: entry.name) others);

  # a profile arrives reduced by the runner to the samples of every stack and,
  # per marker name, of the stacks holding a frame with that name, each stack
  # counted once however deep it recurses. a fleet's raw folded stacks run to
  # hundreds of megabytes, more than an evaluation should read
  sampled = markers: profile: {
    inherit (profile) total;
    byRegion = builtins.listToAttrs (
      map (marker: {
        name = marker.region;
        value = profile.inclusive.${marker.name} or 0;
      }) markers
    );
  };
in
{
  inherit
    discover
    entries
    ambiguous
    sampled
    ;
}
