# counter verdicts against calibrated budgets, and the calibration that sets
# them. a counter regresses only when it moves past its relative tolerance and
# its absolute floor together, the joint rule nix-effects' bench uses, so a
# small counter can't fail a cell on a move that's noise for the workload
{ lib }:
let
  abs = value: if value < 0 then -value else value;

  # tolerances no calibration may go below. counters are exact, so repeated
  # runs of one revision usually observe no noise at all and these decide.
  # these are policy floors, not measured noise. the relative allocation floors
  # follow nix-effects' bench/budgets.toml; heap bytes allow relocation changes
  policy = {
    default = {
      permille = 5;
      floor = 2000;
    };
    heapBytes = {
      permille = 50;
      floor = 65536;
    };
  };

  budgetFor = name: policy.${name} or policy.default;

  # a nondeterministic counter has no single value to judge
  judgeCounter =
    budget: entry:
    let
      beyond =
        abs entry.change >= budget.floor
        && (entry.baseline.value == 0 || abs entry.change * 1000 > entry.baseline.value * budget.permille);
    in
    if entry.nondeterministic then
      "unjudged"
    else if !beyond then
      "within"
    else if entry.change > 0 then
      "regression"
    else
      "improvement";

  cellsOf =
    cells:
    lib.concatLists (
      lib.mapAttrsToList (
        workload: sizes:
        lib.mapAttrsToList (size: result: {
          inherit workload size result;
        }) sizes
      ) cells
    );

  # the gate fails on a counter regression past budget and on a cell the
  # candidate itself failed. a cell rejected for the baseline's sake is listed
  # as unjudged. budgets calibrated on another evaluator judge nothing
  judge =
    {
      budgets,
      evaluator,
      cells,
      counterNames,
    }:
    let
      all = cellsOf cells;
      accepted = builtins.filter (entry: entry.result._tag == "accepted") all;
      rejected = builtins.filter (entry: entry.result._tag == "rejected") all;
      candidateFailures = map (entry: { inherit (entry) workload size; }) (
        builtins.filter (entry: entry.result.candidateFailed) rejected
      );
      unjudged = map (entry: { inherit (entry) workload size; }) (
        builtins.filter (entry: !entry.result.candidateFailed) rejected
      );
      missing = builtins.filter (name: !(budgets.counters ? ${name})) counterNames;
      counterVerdicts =
        result:
        lib.genAttrs counterNames (name: judgeCounter budgets.counters.${name} result.counters.${name});
      byCell = builtins.mapAttrs (
        _: builtins.mapAttrs (_: result: if result._tag == "accepted" then counterVerdicts result else null)
      ) cells;
      regressions = lib.concatMap (
        entry:
        map
          (counter: {
            inherit (entry) workload size;
            inherit counter;
            inherit (entry.result.counters.${counter}) change permille;
            budget = budgets.counters.${counter};
          })
          (
            builtins.filter (
              counter: byCell.${entry.workload}.${entry.size}.${counter} == "regression"
            ) counterNames
          )
      ) accepted;
      unjudgedCounters = lib.concatMap (
        entry:
        map
          (counter: {
            inherit (entry) workload size;
            inherit counter;
          })
          (
            builtins.filter (
              counter: byCell.${entry.workload}.${entry.size}.${counter} == "unjudged"
            ) counterNames
          )
      ) accepted;
      usable = builtins.any (
        entry:
        builtins.any (name: byCell.${entry.workload}.${entry.size}.${name} != "unjudged") counterNames
      ) accepted;
    in
    if budgets == null then
      {
        _tag = "uncalibrated";
        reason = "no budgets were given";
      }
    else if budgets.evaluator != evaluator.version then
      {
        _tag = "uncalibrated";
        reason = "budgets were calibrated on ${budgets.evaluator} and the records come from ${evaluator.version}";
      }
    else if missing != [ ] then
      {
        _tag = "uncalibrated";
        reason = "budgets do not cover counters ${lib.concatStringsSep ", " missing}";
      }
    else if !usable && candidateFailures == [ ] then
      {
        _tag = "uncalibrated";
        reason = "no deterministic counter in an accepted cell could be judged";
      }
    else
      {
        _tag = if regressions == [ ] && candidateFailures == [ ] then "pass" else "fail";
        inherit
          byCell
          regressions
          candidateFailures
          unjudged
          unjudgedCounters
          ;
      };

  # budgets from repeated comparisons of one revision against itself. every
  # move they show is noise, so a tolerance is twice the largest one observed,
  # never below policy. runs from different evaluators can't calibrate together
  calibrate =
    {
      compared,
      counterNames,
    }:
    let
      invalid = builtins.any (result: result._tag != "compared") compared;
      differentSources = builtins.any (
        result:
        result.run.baseline.dirty
        || result.run.candidate.dirty
        || result.run.baseline.revision != result.run.candidate.revision
        || result.run.baseline.narHash != result.run.candidate.narHash
      ) compared;
      evaluators = lib.unique (map (result: result.run.evaluator) compared);
      rejected = lib.concatMap (
        result: builtins.filter (entry: entry.result._tag == "rejected") (cellsOf result.cells)
      ) compared;
      accepted = lib.concatMap (
        result: builtins.filter (entry: entry.result._tag == "accepted") (cellsOf result.cells)
      ) compared;
      observed =
        name:
        let
          entries = map (entry: entry.result.counters.${name}) accepted;
          judged = builtins.filter (entry: !entry.nondeterministic) entries;
          largest = values: builtins.foldl' lib.max 0 values;
          # round noise outward so the displayed integer cannot narrow a budget
          relative = entry: (abs entry.change * 1000 + entry.baseline.value - 1) / entry.baseline.value;
        in
        {
          change = largest (map (entry: abs entry.change) judged);
          permille = largest (map relative (builtins.filter (entry: entry.baseline.value != 0) judged));
          nondeterministic = builtins.length entries - builtins.length judged;
        };
      tolerance =
        name:
        let
          seen = observed name;
          floor = budgetFor name;
        in
        {
          permille = lib.max floor.permille (2 * seen.permille);
          floor = lib.max floor.floor (2 * seen.change);
          observed = seen;
        };
      uncovered = builtins.filter (
        name: builtins.all (entry: entry.result.counters.${name}.nondeterministic) accepted
      ) counterNames;
    in
    if invalid then
      throw "calibration needs accepted comparisons"
    else if differentSources then
      throw "calibration needs clean, identical source content at one revision on both sides of every run"
    else if builtins.length evaluators != 1 then
      throw "calibration needs runs from one evaluator, these come from ${
        lib.concatMapStringsSep ", " (evaluator: "${evaluator.version} at ${evaluator.outPath}") evaluators
      }"
    else if rejected != [ ] then
      throw "calibration contains rejected cells, ${
        lib.concatMapStringsSep ", " (entry: "${entry.workload} at ${entry.size}") rejected
      }"
    else if accepted == [ ] then
      throw "calibration needs at least one accepted cell"
    else if uncovered != [ ] then
      throw "calibration has no deterministic observations for counters ${lib.concatStringsSep ", " uncovered}"
    else
      {
        evaluator = (builtins.head evaluators).version;
        calibration = {
          revisions = lib.unique (
            lib.concatMap (result: [
              result.run.baseline.revision
              result.run.candidate.revision
            ]) compared
          );
          machines = lib.unique (lib.concatMap (entry: entry.result.machines) accepted);
          runs = builtins.length compared;
          cells = builtins.length accepted;
        };
        counters = lib.genAttrs counterNames tolerance;
      };
in
{
  inherit judge calibrate;
}
