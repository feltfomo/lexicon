# the marker invariant over every markers.nix in the tree. a marker is an identity
# lambda defined alone on its line, so call counts and profiler frames attribute
# to it, and applying it changes neither a value nor what gets forced
{ lib }:
let
  analysis = import ../../bench/analysis { inherit lib; };
  markers = analysis.discover ../..;

  lineOf =
    marker: builtins.elemAt (lib.splitString "\n" (builtins.readFile marker.file)) (marker.line - 1);

  definedBy = marker: (import marker.file).${marker.name};

  samples = [
    {
      nested.list = [
        1
        "two"
      ];
    }
    [
      null
      3.5
    ]
    "text"
    42
  ];

  # one case per marker, so a failure names its region
  perMarker =
    describe: case:
    builtins.listToAttrs (
      map (marker: {
        name = "test ${marker.region} ${describe}";
        value = case marker;
      }) markers
    );
in
{
  tests = {
    "test every owner the workloads exercise defines its markers" = {
      expr = map (marker: marker.region) markers;
      expected = [
        "src/declarations.compileDeclaration"
        "src/declarations.prepareDeclaration"
        "src/furnish.compileManifest"
        "src/furnish.indexCollisions"
        "src/ownerships.mergeContributions"
        "src/ownerships.resolveContext"
        "src/praxis.compileProject"
        "src/praxis.normalizeCommands"
        "src/program.inventoryDirectory"
        "src/program/theme.composeThemes"
        "src/toml.renderDocument"
      ];
    };

    "test every marker has a position of its own" = {
      expr = builtins.length (
        lib.unique (map (marker: "${marker.file}:${toString marker.line}") markers)
      );
      expected = builtins.length markers;
    };

    # a shared helper taking the region name would put every region at one position
    "test every marker is an identity lambda alone on its line" = {
      expr = builtins.filter (
        marker:
        let
          # the evaluator's regex has no backreferences, so the two names compare here
          parts = builtins.match " *${marker.name} = ([a-z][A-Za-z]*): ([a-z][A-Za-z]*);" (lineOf marker);
        in
        parts == null || builtins.head parts != lib.last parts
      ) markers;
      expected = [ ];
    };

    "test marker names are unique across owners" = {
      expr = lib.unique (map (marker: marker.name) markers) == map (marker: marker.name) markers;
      expected = true;
    };
  }
  // perMarker "changes no value" (marker: {
    expr = map (definedBy marker) samples;
    expected = samples;
  })
  // perMarker "leaves a throwing argument unforced until demanded" (marker: {
    expr = builtins.length [ (definedBy marker (throw "${marker.region} forced its argument")) ];
    expected = 1;
  })
  // perMarker "forces its argument when its result is demanded" (marker: {
    expr = definedBy marker (throw "${marker.region} forced its argument");
    expectedError.type = "ThrownError";
    expectedError.msg = "${lib.escapeRegex marker.region} forced its argument";
  });
}
