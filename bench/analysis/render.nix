# renders a comparison as markdown. it reports deltas only. budgets and verdicts
# need a calibration run first, so nothing here judges a change
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

  header = run: ''
    # Lexicon evaluation benchmark

    - ${side "baseline" run.baseline}
    - ${side "candidate" run.candidate}
    - evaluator ${run.evaluator.version} at ${run.evaluator.outPath}, system ${run.system}
    - schedule one warm-up per side, then baseline and candidate, candidate and baseline, baseline and candidate
    - timeout ${toString run.timeoutSeconds} seconds per sample, killed with SIGKILL

    Counters are exact for one evaluator and expression and come from the measured samples. A
    counter that differs between samples of one side shows its median and is marked
    nondeterministic. Timing is reported, never judged. No budgets exist yet, so this report has no
    verdicts.
  '';

  summary =
    cells:
    table
      [
        "workload"
        "size"
        "status"
        "function calls"
        "thunks"
        "heap bytes"
        "wall ms"
      ]
      (
        lib.concatLists (
          lib.mapAttrsToList (
            workload: sizes:
            map (
              size:
              let
                result = sizes.${size};
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
                ]
            ) (sizeOrder (builtins.attrNames sizes))
          ) cells
        )
      );

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

  detail =
    workload: sizes:
    let
      accepted = builtins.filter (size: sizes.${size}._tag == "accepted") (
        sizeOrder (builtins.attrNames sizes)
      );
      counterNames = map (counter: counter.name) counters;
      counterTable = table ([ "counter" ] ++ accepted) (
        map (name: [ name ] ++ map (size: change sizes.${size}.counters.${name}) accepted) counterNames
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
      moved =
        size: lib.filterAttrs (_: entry: entry.change != 0 || entry.nondeterministic) sizes.${size}.owners;
      ownerLines =
        size:
        let
          entries = moved size;
        in
        if entries == { } then
          "- ${size}: no owner's applications moved\n"
        else
          lib.concatStrings (
            lib.mapAttrsToList (owner: entry: "- ${size}: ${owner} ${change entry}\n") entries
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
    ${header result.run}
    ## Summary

    ${summary result.cells}

    ## Rejected cells

    ${rejected result.cells}
    ## Declared limits

    ${limits result.limits}
    ## Workloads

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList detail result.cells)}''
