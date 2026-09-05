{
  lib,
  krisis,
  ...
}:
let
  reporter = krisis.mkReporter {
    formatHeader = count: "program: ${toString count} declaration error(s)";
    formatDiagnostic = diagnostic: "  - " + krisis.renderPlain diagnostic;
  };
  suggest = candidates: name: krisis.suggest name candidates;
in
{
  inherit reporter suggest;
  inherit (krisis) editDistance;
  inherit (reporter) finish;

  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "program";
  };

  duplicateValues =
    values:
    values
    |> builtins.groupBy (value: value)
    |> lib.filterAttrs (_: group: builtins.length group > 1)
    |> builtins.attrNames;

  suggestionFor =
    candidates: name:
    let
      match = suggest candidates name;
    in
    if match == null then "" else " -- did you mean '${match}'?";
}
