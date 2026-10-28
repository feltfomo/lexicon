# renders a comparison as markdown. counters carry verdicts when the budgets
# were calibrated on the records' evaluator; everything else is reported only
{ lib, counters }:
let
  signed = value: if value > 0 then "+${toString value}" else toString value;

  permille = value: if value == null then "n/a" else "${signed value}‰";

  # a flagged counter keeps its median so the size of the noise stays visible
  change =
    entry:
    "${toString entry.baseline.value} → ${toString entry.candidate.value} (${signed entry.change}, ${permille entry.permille})"
    + lib.optionalString entry.nondeterministic " nondeterministic";

  orNone = value: if value == null then "n/a" else toString value;

  # load averages arrive as floats, which toString prints with six decimals
  hundredths =
    value:
    let
      scaled = builtins.floor (value * 100 + 0.5);
      fraction = lib.mod scaled 100;
    in
    "${toString (scaled / 100)}.${lib.optionalString (fraction < 10) "0"}${toString fraction}";

  row = cells: "| ${lib.concatStringsSep " | " cells} |";

  table =
    header: rows:
    lib.concatStringsSep "\n" (
      [
        (row header)
        (row (map (_: "---") header))
      ]
      ++ map row rows
    );

  sizeOrder = sizes: builtins.sort (a: b: lib.toInt a < lib.toInt b) sizes;

  side =
    name: entry:
    "${name} ${entry.spec} at ${entry.revision}${lib.optionalString entry.dirty " with uncommitted changes"}, snapshot ${entry.source}";

  calibrated = verdict: verdict._tag == "pass" || verdict._tag == "fail";

  counterVerdict =
    verdict: workload: size: name:
    if calibrated verdict then verdict.byCell.${workload}.${size}.${name} else null;

  header = run: verdict: ''
    # Lexicon evaluation benchmark

    - ${side "baseline" run.baseline}
    - ${side "candidate" run.candidate}
    - evaluator ${run.evaluator.version} at ${run.evaluator.outPath}, system ${run.system}
    - schedule ${lib.concatMapStringsSep ", " (step: "${step.phase} ${step.side}") run.schedule}
    - timeout ${toString run.timeoutSeconds} seconds per sample, killed with SIGKILL

    Counters are exact for one evaluator and expression and come from the measured samples. A
    counter that differs between samples of one side shows its median, is marked
    nondeterministic and gets no verdict. Timing, marker samples and owner applications are
    reported, never judged. ${
      if calibrated verdict then
        "A counter regresses when it moves past its budget's relative tolerance and absolute floor together."
      else
        "This report has no verdicts, because ${verdict.reason}."
    }

    Verdict: ${verdict._tag}
  '';

  # the counters that didn't stay within budget, or the cell's status when it has none
  cellVerdict =
    verdict: workload: size: result:
    if result._tag == "rejected" then
      if !(calibrated verdict) then
        "n/a"
      else if result.candidateFailed then
        "candidate failed"
      else
        "unjudged"
    else if !(calibrated verdict) then
      "n/a"
    else
      let
        verdicts = verdict.byCell.${workload}.${size};
        named =
          kind:
          lib.optional (builtins.any (name: verdicts.${name} == kind) (builtins.attrNames verdicts))
            "${kind} ${
              lib.concatStringsSep ", " (
                builtins.filter (name: verdicts.${name} == kind) (builtins.attrNames verdicts)
              )
            }";
        notable = named "regression" ++ named "improvement" ++ named "unjudged";
      in
      if notable == [ ] then "within" else lib.concatStringsSep "; " notable;

  summary =
    verdict: cells:
    table
      [
        "workload"
        "size"
        "status"
        "function calls"
        "thunks"
        "heap bytes"
        "wall ms"
        "verdict"
      ]
      (
        lib.concatLists (
          lib.mapAttrsToList (
            workload: sizes:
            map (
              size:
              let
                result = sizes.${size};
                judged = cellVerdict verdict workload size result;
              in
              if result._tag == "rejected" then
                [
                  workload
                  size
                  "rejected"
                  ""
                  ""
                  ""
                  ""
                  judged
                ]
              else
                [
                  workload
                  size
                  "accepted"
                  (change result.counters.nrFunctionCalls)
                  (change result.counters.nrThunks)
                  (change result.counters.heapBytes)
                  "${orNone result.timing.wallMs.baseline} → ${orNone result.timing.wallMs.candidate}"
                  judged
                ]
            ) (sizeOrder (builtins.attrNames sizes))
          ) cells
        )
      );

  verdictSection =
    verdict:
    if !(calibrated verdict) then
      "No verdicts, because ${verdict.reason}.\n"
    else
      let
        regressions = map (
          entry:
          "- ${entry.workload} at ${entry.size}: ${entry.counter} ${signed entry.change} (${permille entry.permille}), budget ${toString entry.budget.permille}‰ and ${toString entry.budget.floor}\n"
        ) verdict.regressions;
        failures = map (
          entry: "- ${entry.workload} at ${entry.size}: the candidate failed\n"
        ) verdict.candidateFailures;
        unjudged = map (
          entry:
          "- ${entry.workload} at ${entry.size}: unjudged, the cell was rejected without a candidate failure\n"
        ) verdict.unjudged;
        unjudgedCounters = map (
          entry: "- ${entry.workload} at ${entry.size}: ${entry.counter} is nondeterministic and unjudged\n"
        ) verdict.unjudgedCounters;
        lines = regressions ++ failures ++ unjudged ++ unjudgedCounters;
      in
      if lines == [ ] then
        "Every judged counter stayed within budget or improved.\n"
      else
        lib.concatStrings lines;

  rejected =
    cells:
    let
      entries = lib.concatLists (
        lib.mapAttrsToList (
          workload: sizes:
          lib.concatMap (
            size:
            let
              result = sizes.${size};
            in
            lib.optional (result._tag == "rejected") (
              "- ${workload} at ${size}\n" + lib.concatMapStrings (reason: "  - ${reason}\n") result.reasons
            )
          ) (sizeOrder (builtins.attrNames sizes))
        ) cells
      );
    in
    if entries == [ ] then "No cell was rejected.\n" else lib.concatStrings entries;

  limits =
    declared:
    if declared == { } then
      "No declared limits.\n"
    else
      lib.concatStrings (
        lib.mapAttrsToList (name: reason: "- ${name} is declared and can't run, ${reason}\n") declared
      );

  markerList =
    markers:
    let
      describe = side: lib.concatMapStringsSep ", " (marker: marker.region) markers.${side};
    in
    ''
      - baseline ${if markers.baseline == [ ] then "defines no marker" else describe "baseline"}
      - candidate ${if markers.candidate == [ ] then "defines no marker" else describe "candidate"}
    '';

  # one marker's entries, compared when both sides define it
  entries =
    region:
    if region._tag == "both" then
      change region
    else if region._tag == "candidateOnly" then
      "candidate only, ${toString region.candidate.value}"
    else
      "baseline only, ${toString region.baseline.value}";

  sampledCell =
    regions: region:
    let
      entry = regions.${region} or null;
    in
    if entry == null then
      "n/a"
    else if entry._tag == "ambiguous" then
      "ambiguous"
    else
      "${toString entry.samples} of ${toString entry.total}";

  detail =
    verdict: workload: sizes:
    let
      accepted = builtins.filter (size: sizes.${size}._tag == "accepted") (
        sizeOrder (builtins.attrNames sizes)
      );
      counterNames = map (counter: counter.name) counters;
      judged =
        size: name:
        let
          kind = counterVerdict verdict workload size name;
        in
        change sizes.${size}.counters.${name} + lib.optionalString (kind != null) " ${kind}";
      counterTable = table ([ "counter" ] ++ accepted) (
        map (name: [ name ] ++ map (size: judged size name) accepted) counterNames
      );
      timingTable = table ([ "timing, baseline → candidate median" ] ++ accepted) (
        map
          (
            name:
            [ name ]
            ++ map (
              size:
              let
                entry = sizes.${size}.timing.${name};
              in
              "${orNone entry.baseline} → ${orNone entry.candidate}"
            ) accepted
          )
          [
            "wallMs"
            "cpuMs"
            "peakRssKiB"
            "heapSize"
          ]
      );
      # a region shows when either side entered it at some size. which side
      # defines a region is listed once for the whole run
      entered =
        region:
        builtins.any (
          size:
          let
            entry = sizes.${size}.markers.${region};
          in
          (entry.baseline.value or 0) != 0 || (entry.candidate.value or 0) != 0
        ) accepted;
      regions = builtins.filter entered (
        lib.unique (lib.concatMap (size: builtins.attrNames sizes.${size}.markers) accepted)
      );
      markerTable =
        if regions == [ ] then
          "No marker was entered.\n"
        else
          table ([ "marker entries" ] ++ accepted) (
            map (region: [ region ] ++ map (size: entries sizes.${size}.markers.${region}) accepted) regions
          )
          + "\n";
      sampledTable =
        if regions == [ ] then
          ""
        else
          table ([ "inclusive samples, baseline → candidate" ] ++ accepted) (
            map (
              region:
              [ region ]
              ++ map (
                size:
                "${sampledCell sizes.${size}.sampled.baseline region} → ${
                  sampledCell sizes.${size}.sampled.candidate region
                }"
              ) accepted
            ) regions
          )
          + "\n";
      moved =
        size: lib.filterAttrs (_: entry: entry.change != 0 || entry.nondeterministic) sizes.${size}.owners;
      ownerLines =
        size:
        let
          moves = moved size;
        in
        if moves == { } then
          "- ${size}: no owner's applications moved\n"
        else
          lib.concatStrings (
            lib.mapAttrsToList (owner: entry: "- ${size}: ${owner} ${change entry}\n") moves
          );
      machines = lib.unique (lib.concatMap (size: sizes.${size}.machines) accepted);
      loads = lib.concatMap (size: sizes.${size}.loads) accepted;
    in
    if accepted == [ ] then
      "### ${workload}\n\nEvery size was rejected.\n"
    else
      ''
        ### ${workload}

        ${counterTable}

        ${markerTable}
        ${sampledTable}
        Applications by owner that moved

        ${lib.concatMapStrings ownerLines accepted}
        ${timingTable}

        Machines ${lib.concatStringsSep ", " machines}, one-minute load at launch from ${hundredths (builtins.head (builtins.sort builtins.lessThan loads))} to ${hundredths (lib.last (builtins.sort builtins.lessThan loads))}.
      '';
in
result:
if result._tag == "refused" then
  throw "benchmark comparison refused, ${lib.concatStringsSep "; " result.reasons}"
else
  ''
    ${header result.run result.verdict}
    ## Summary

    ${summary result.verdict result.cells}

    ## Verdicts

    ${verdictSection result.verdict}
    ## Rejected cells

    ${rejected result.cells}
    ## Declared limits

    ${limits result.limits}
    ## Markers

    ${markerList result.markers}
    Marker entries are exact call counts of each marker's lambda. Inclusive samples count the
    profiler stacks that hold a marker's frame, out of every stack sampled in that side's one
    profiling run, at ${toString (result.run.profileFrequency or 1000)} samples a second at most. A
    marker forces only its argument's weak head normal form, so later demand on the value isn't
    inside it. A region is ambiguous when another applied lambda shares its marker's name.

    ## Workloads

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (detail result.verdict) result.cells)}''
