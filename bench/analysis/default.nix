# the comparison analysis over collected records. it's pure, so the report and
# the tests share every rule. a record is a sample's runner metadata, the
# evaluator's statistics or reduced profile, and the hash of its projection.
# records come in cells, one per workload and size, and a cell is accepted or
# rejected whole
{ lib }:
let
  markerRules = import ./markers.nix { inherit lib; };
  verdicts = import ./verdicts.nix { inherit lib; };
  statisticsFailures = import ./statistics.nix { inherit lib; };

  sides = [
    "baseline"
    "candidate"
  ];

  # the gate signal. each is deterministic for one evaluator and expression, so
  # a counter that moves between samples of one side is flagged, not averaged
  counters = [
    {
      name = "nrFunctionCalls";
      get = stats: stats.nrFunctionCalls;
    }
    {
      name = "nrPrimOpCalls";
      get = stats: stats.nrPrimOpCalls;
    }
    {
      name = "nrThunks";
      get = stats: stats.nrThunks;
    }
    {
      name = "values.number";
      get = stats: stats.values.number;
    }
    {
      name = "envs.number";
      get = stats: stats.envs.number;
    }
    {
      name = "sets.number";
      get = stats: stats.sets.number;
    }
    {
      name = "list.elements";
      get = stats: stats.list.elements;
    }
    {
      name = "list.concats";
      get = stats: stats.list.concats;
    }
    {
      name = "nrOpUpdates";
      get = stats: stats.nrOpUpdates;
    }
    {
      name = "nrOpUpdateValuesCopied";
      get = stats: stats.nrOpUpdateValuesCopied;
    }
    {
      name = "heapBytes";
      get = stats: stats.values.bytes + stats.envs.bytes + stats.sets.bytes + stats.list.bytes;
    }
  ];

  median =
    values:
    let
      sorted = builtins.sort builtins.lessThan values;
      count = builtins.length sorted;
      middle = count / 2;
    in
    if count == 0 then
      null
    else if lib.mod count 2 == 1 then
      builtins.elemAt sorted middle
    else
      (builtins.elemAt sorted (middle - 1) + builtins.elemAt sorted middle) / 2;

  allEqual = values: values == [ ] || builtins.all (value: value == builtins.head values) values;

  # a position's owner is the directory of its file inside lexicon or the bench
  # tree, or the input it was fetched from. revisions and narHashes are dropped,
  # so the same owner on both sides compares even when its store path differs
  ownerOf =
    { source, bench }:
    file:
    let
      under = root: root != null && lib.hasPrefix "${root}/" file;
      relative = root: builtins.dirOf (lib.removePrefix "${root}/" file);
      fetched = builtins.match "«([^?»]*)[^»]*»/.*" file;
      reference = builtins.head fetched;
      parts = lib.splitString "/" reference;
      revision = builtins.match "[0-9a-f]{40}" (lib.last parts) != null;
      stored = builtins.match "${builtins.storeDir}/[a-z0-9]{32}-([^/]*)/.*" file;
    in
    if file == null then
      "unpositioned"
    else if under source then
      relative source
    else if under bench then
      relative bench
    else if fetched != null then
      if revision then lib.concatStringsSep "/" (lib.init parts) else reference
    else if stored != null then
      "store:${builtins.head stored}"
    else
      "other";

  owners =
    roots: stats:
    builtins.foldl' (
      totals: entry:
      let
        owner = ownerOf roots (entry.file or null);
      in
      totals // { ${owner} = (totals.${owner} or 0) + entry.count; }
    ) { } stats.functions;

  required = [
    "workload"
    "size"
    "order"
    "side"
    "phase"
    "exit"
    "timedOut"
    "wallNs"
    "peakRssKiB"
    "machine"
    "load"
    "source"
    "evaluator"
  ];

  # one sample normalized. failures are independent, so every one is listed;
  # counters, owners and marker entries are only read from a counting sample
  # without failures, and marker samples only from a profiling one. counting and
  # profiling never share a process, so each sample carries one or the other
  sample =
    {
      name,
      expected,
      meta,
      stats,
      profile ? null,
      projection,
      bench,
      markers ? {
        baseline = [ ];
        candidate = [ ];
      },
    }:
    let
      missing =
        if !builtins.isAttrs meta then required else builtins.filter (field: !(meta ? ${field})) required;
      natural = value: builtins.isInt value && value >= 0;
      types = {
        workload = builtins.isString;
        size = natural;
        order = natural;
        side = value: builtins.elem value sides;
        phase = builtins.isString;
        exit = natural;
        timedOut = builtins.isBool;
        wallNs = natural;
        peakRssKiB = value: value == null || natural value;
        machine = builtins.isString;
        load = value: builtins.isInt value || builtins.isFloat value;
        source = builtins.isString;
        evaluator =
          value:
          builtins.isAttrs value
          && builtins.isString (value.version or null)
          && builtins.isString (value.outPath or null);
      };
      invalid =
        if missing != [ ] then [ ] else builtins.filter (field: !types.${field} meta.${field}) required;
      malformed = missing != [ ] || invalid != [ ];
      profiling = expected.phase == "profile";
      sideMarkers = markers.${expected.side};
      identity = [
        "workload"
        "size"
        "order"
        "side"
        "phase"
        "source"
        "evaluator"
      ];
      mismatched =
        if malformed then [ ] else builtins.filter (field: meta.${field} != expected.${field}) identity;
      validProfile =
        builtins.isAttrs profile
        && builtins.isInt (profile.total or null)
        && profile.total > 0
        && builtins.isAttrs (profile.inclusive or null)
        && builtins.all (count: natural count && count <= profile.total) (
          builtins.attrValues profile.inclusive
        );
      failures =
        if missing != [ ] then
          [ "${name} has a malformed record missing ${lib.concatStringsSep ", " missing}" ]
        else if invalid != [ ] then
          [ "${name} has malformed metadata fields ${lib.concatStringsSep ", " invalid}" ]
        else
          lib.optional (
            mismatched != [ ]
          ) "${name} metadata differs from its run or cell in ${lib.concatStringsSep ", " mismatched}"
          ++ lib.optional meta.timedOut "${name} timed out"
          ++ lib.optional (!meta.timedOut && meta.exit != 0) "${name} exited ${toString meta.exit}"
          ++ (
            if profiling then
              lib.optional (profile == null) "${name} wrote no profile"
              ++ lib.optional (projection == null) "${name} wrote no projection"
            else
              lib.optional (stats == null) "${name} wrote no statistics"
              ++ lib.optional (projection == null) "${name} wrote no projection"
          );
    in
    {
      inherit name projection failures;
      inherit (expected)
        side
        phase
        source
        order
        ;
      evaluator = if malformed then null else meta.evaluator;
      instrumentationFailures =
        if profiling then
          lib.optional (!validProfile) "${name} has a malformed reduced profile"
        else
          map (reason: "${name} ${reason}") (statisticsFailures stats);
      counters = builtins.listToAttrs (
        map (counter: {
          inherit (counter) name;
          value = counter.get stats;
        }) counters
      );
      owners = owners {
        inherit (meta) source;
        inherit bench;
      } stats;
      markers = markerRules.entries sideMarkers stats;
      ambiguous = markerRules.ambiguous sideMarkers stats;
      sampled = markerRules.sampled sideMarkers profile;
      timing = {
        inherit (meta) machine load;
        wallMs = meta.wallNs / 1000000;
        peakRssKiB = meta.peakRssKiB or null;
        cpuMs = if stats ? cpuTime then builtins.floor (stats.cpuTime * 1000) else null;
        heapSize = stats.gc.heapSize or null;
      };
    };

  # a side's aggregate over its measured samples. a value that differs between
  # samples keeps its median and is flagged nondeterministic
  aggregate =
    get: samples:
    let
      values = map get samples;
    in
    {
      value = median values;
      deterministic = allEqual values;
    };

  delta =
    baseline: candidate:
    let
      change = candidate.value - baseline.value;
    in
    {
      inherit baseline candidate change;
      permille = if baseline.value == 0 then null else change * 1000 / baseline.value;
      nondeterministic = !(baseline.deterministic && candidate.deterministic);
    };

  inPhase =
    phase: samples: side:
    builtins.filter (sample: sample.phase == phase && sample.side == side) samples;

  # a marker defined on one side only is reported as such and never compared,
  # since its absence means the region isn't marked there, not that it's empty
  markerRegions =
    markers: baseline: candidate:
    let
      regionsOf = side: map (marker: marker.region) markers.${side};
      present = {
        baseline = regionsOf "baseline";
        candidate = regionsOf "candidate";
      };
      names = lib.unique (present.baseline ++ present.candidate);
      on = side: region: builtins.elem region present.${side};
      # samples of the other side never mention a one-sided region
      entriesOf = samples: region: aggregate (sample: sample.markers.${region}) samples;
    in
    lib.genAttrs names (
      region:
      if !(on "baseline" region) then
        {
          _tag = "candidateOnly";
          candidate = entriesOf candidate region;
        }
      else if !(on "candidate" region) then
        {
          _tag = "baselineOnly";
          baseline = entriesOf baseline region;
        }
      else
        {
          _tag = "both";
        }
        // delta (entriesOf baseline region) (entriesOf candidate region)
    );

  # inclusive samples per region from one profile per side. the count samples
  # of the same side show whether another applied lambda shares a marker's name
  sampledRegions =
    markers: measured: profiled: side:
    let
      profile = lib.findFirst (_: true) null (profiled side);
      ambiguous = lib.unique (lib.concatMap (sample: sample.ambiguous) (measured side));
    in
    if profile == null then
      { }
    else
      builtins.listToAttrs (
        map (marker: {
          name = marker.region;
          value =
            if builtins.elem marker.name ambiguous then
              { _tag = "ambiguous"; }
            else
              {
                _tag = "sampled";
                samples = profile.sampled.byRegion.${marker.region};
                inherit (profile.sampled) total;
              };
        }) markers.${side}
      );

  # a cell is rejected whole by any failed sample, a schedule that didn't run to
  # the end, or a projection that differs anywhere. the projection check only
  # runs once every sample has one, since it depends on them
  cell =
    { schedule, markers }:
    samples:
    let
      expected = builtins.length schedule;
      shape = map (sample: { inherit (sample) phase side order; }) samples;
      ordered = lib.imap0 (order: step: step // { inherit order; }) schedule;
      incomplete =
        lib.optional
          (shape != lib.take (builtins.length samples) ordered || builtins.length samples != expected)
          "the schedule did not complete in order, found ${toString (builtins.length samples)} of ${toString expected} samples";
      admissionFailures = lib.concatMap (sample: sample.failures) samples ++ incomplete;
      failures =
        admissionFailures
        ++ lib.optionals (admissionFailures == [ ]) (
          lib.concatMap (sample: sample.instrumentationFailures) samples
        );
      projections = side: map (sample: sample.projection) (builtins.filter (s: s.side == side) samples);
      # a failed or unstable candidate sample is the candidate's fault whatever the
      # baseline did. a baseline failure or a differing projection leaves the cell
      # unjudged instead, since no cost comparison exists to fail
      candidateFailed =
        builtins.any (
          sample:
          sample.side == "candidate"
          && (sample.failures != [ ] || (admissionFailures == [ ] && sample.instrumentationFailures != [ ]))
        ) samples
        || !allEqual (projections "candidate");
      unstable = lib.concatMap (
        side:
        lib.optional (!allEqual (projections side)) "the ${side} projection differs between its samples"
      ) sides;
      mismatch = lib.optional (
        unstable == [ ] && builtins.head (projections "baseline") != builtins.head (projections "candidate")
      ) "the baseline and candidate projections differ";
      reasons = if failures != [ ] then failures else unstable ++ mismatch;
      measured = inPhase "measure" samples;
      profiled = inPhase "profile" samples;
      baseline = measured "baseline";
      candidate = measured "candidate";
      compare = get: delta (aggregate get baseline) (aggregate get candidate);
      ownerNames = lib.unique (
        lib.concatMap (sample: builtins.attrNames sample.owners) (baseline ++ candidate)
      );
      timing = name: {
        baseline = median (builtins.filter (value: value != null) (map (s: s.timing.${name}) baseline));
        candidate = median (builtins.filter (value: value != null) (map (s: s.timing.${name}) candidate));
      };
    in
    if reasons != [ ] then
      {
        _tag = "rejected";
        inherit reasons candidateFailed;
      }
    else
      {
        _tag = "accepted";
        counters = builtins.listToAttrs (
          map (counter: {
            inherit (counter) name;
            value = compare (sample: sample.counters.${counter.name});
          }) counters
        );
        owners = lib.genAttrs ownerNames (owner: compare (sample: sample.owners.${owner} or 0));
        markers = markerRegions markers baseline candidate;
        sampled = {
          baseline = sampledRegions markers measured profiled "baseline";
          candidate = sampledRegions markers measured profiled "candidate";
        };
        timing = lib.genAttrs [
          "peakRssKiB"
          "heapSize"
          "wallMs"
          "cpuMs"
        ] timing;
        machines = lib.unique (map (sample: sample.timing.machine) samples);
        loads = map (sample: sample.timing.load) samples;
      };

  # comparisons refuse before any cell is read when records come from different
  # evaluators or the baseline wasn't clean, since no delta would mean anything
  refusal =
    run: samples:
    let
      evaluators = lib.unique (
        [ run.evaluator ]
        ++ map (sample: sample.evaluator) (builtins.filter (s: s.evaluator != null) samples)
      );
      describe = evaluator: "${evaluator.version} at ${evaluator.outPath}";
    in
    lib.optional (builtins.length evaluators > 1)
      "records come from different evaluators: ${lib.concatMapStringsSep ", " describe evaluators}"
    ++ lib.optional run.baseline.dirty "the baseline source ${run.baseline.spec} was dirty";

  compare =
    {
      run,
      cells,
      limits,
      markers ? {
        baseline = [ ];
        candidate = [ ];
      },
      budgets ? null,
    }:
    let
      samples = lib.concatMap (sizes: lib.concatLists (builtins.attrValues sizes)) (
        builtins.attrValues cells
      );
      reasons = refusal run samples;
      judged = builtins.mapAttrs (
        _:
        builtins.mapAttrs (
          _: samples:
          cell {
            inherit (run) schedule;
            inherit markers;
          } samples
        )
      ) cells;
    in
    if reasons != [ ] then
      {
        _tag = "refused";
        inherit reasons;
      }
    else
      {
        _tag = "compared";
        inherit run limits markers;
        cells = judged;
        verdict = verdicts.judge {
          inherit budgets;
          inherit (run) evaluator;
          cells = judged;
          counterNames = map (counter: counter.name) counters;
        };
      };
in
{
  inherit
    counters
    ownerOf
    sample
    cell
    compare
    median
    ;
  inherit (markerRules) discover;
  calibrate =
    compared:
    verdicts.calibrate {
      inherit compared;
      counterNames = map (counter: counter.name) counters;
    };
  render = import ./render.nix { inherit lib counters; };
}
