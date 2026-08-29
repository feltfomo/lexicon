# one diagnostics policy for the whole program subsystem. program.nix builds
# declarations, the theme compiler elaborates them, and the matugen runtime
# module aggregates cross-aspect entries, and an author gets the same error
# shape from all three.
{
  lib,
  krisis,
  axiom,
}:
let
  reporter = krisis.mkReporter {
    formatHeader = count: "program: ${toString count} declaration error(s)";
    formatDiagnostic = diagnostic: "  - " + krisis.renderPlain diagnostic;
  };

  # every closed key vocabulary in the subsystem wants the same "did you mean"
  # on an unknown name, so the distance lives with the diagnostics policy rather
  # than next to whichever schema needed it first. the suggester binds here
  # rather than in the returned set because an attribute set does not see its
  # own names.
  editDistance =
    a: b:
    let
      aChars = lib.stringToCharacters a;
      bChars = lib.stringToCharacters b;
      bLen = builtins.length bChars;
      columns = lib.range 0 (bLen - 1);
      step =
        previous: i:
        let
          aChar = builtins.elemAt aChars i;
          go =
            row: j:
            row
            ++ [
              (lib.min (lib.min (builtins.elemAt previous (j + 1) + 1) (builtins.elemAt row j + 1)) (
                builtins.elemAt previous j + (if aChar == builtins.elemAt bChars j then 0 else 1)
              ))
            ];
        in
        builtins.foldl' go [ (i + 1) ] columns;
    in
    builtins.elemAt (builtins.foldl' step (lib.range 0 bLen) (
      lib.range 0 (builtins.length aChars - 1)
    )) bLen;

  # a short name has to be a near-exact match before it is worth guessing at.
  # "pkg" is one edit away from far too much to be useful.
  suggest =
    candidates: name:
    let
      threshold = if builtins.stringLength name <= 4 then 1 else 3;
      ranked = builtins.sort (x: y: x.distance < y.distance) (
        builtins.filter (entry: entry.distance <= threshold) (
          map (candidate: {
            inherit candidate;
            distance = editDistance name candidate;
          }) candidates
        )
      );
    in
    if ranked == [ ] then null else (builtins.head ranked).candidate;
in
{
  inherit reporter editDistance suggest;

  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "program";
  };

  # the one place accumulated program diagnostics turn into a failure, so
  # callers stop each deciding how to end a validation
  finish = axiom.validation.finish reporter.fail;

  # every duplicate-registration check groups by id and names the repeats.
  duplicateValues =
    values:
    builtins.attrNames (
      lib.filterAttrs (_: group: builtins.length group > 1) (builtins.groupBy (value: value) values)
    );

  # the trailing clause an unknown-key message appends, empty when nothing is
  # close enough to name.
  suggestionFor =
    candidates: name:
    let
      match = suggest candidates name;
    in
    if match == null then "" else " -- did you mean '${match}'?";
}
