# renders one collected run with the budgets of the analysis's own revision,
# which is the candidate's. the runner reads text for report.md and verdict
# for its exit status
{ lib, dir }:
let
  analysis = import ./. { inherit lib; };
  records = import ./records.nix { inherit lib dir; };
  result = analysis.compare (records // { budgets = import ../budgets.nix; });
in
{
  text = analysis.render result;
  verdict = result.verdict._tag;
}
