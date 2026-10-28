# the comparison analysis over collected records. it's pure, so the report and
# the tests share every rule. a record is a sample's runner metadata, the
# evaluator's statistics and the hash of its projection. records come in cells,
# one per workload and size, and a cell is accepted or rejected whole
{ lib }:
let
  schedule = import ../runner/schedule.nix;

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
    "side"
    "phase"
    "exit"
    "timedOut"
    "wallNs"
    "machine"
    "load"
    "source"
    "evaluator"
  ];

  # one sample normalized. failures are independent, so every one is listed;
  # counters and owners are only read from a sample without failures
  sample =
    {
      name,
      meta,
      stats,
      projection,
      bench,
    }:
    let
      missing = if meta == null then required else builtins.filter (field: !(meta ? ${field})) required;
      malformed = missing != [ ];
      callSum = builtins.foldl' (total: entry: total + entry.count) 0 (stats.functions or [ ]);
      failures =
        if malformed then
          [ "${name} has a malformed record missing ${lib.concatStringsSep ", " missing}" ]
        else
          lib.optional meta.timedOut "${name} timed out"
          ++ lib.optional (!meta.timedOut && meta.exit != 0) "${name} exited ${toString meta.exit}"
          ++ lib.optional (stats == null) "${name} wrote no statistics"
          ++ lib.optional (projection == null) "${name} wrote no projection"
          ++ lib.optional (stats != null && !(stats ? functions)) "${name} has statistics without call counts"
          ++ lib.optional (
            stats != null && stats ? functions && callSum != stats.nrFunctionCalls
          ) "${name} call counts sum to ${toString callSum}, not nrFunctionCalls";
    in
    {
      inherit name projection failures;
      side = if malformed then null else meta.side;
      phase = if malformed then null else meta.phase;
      evaluator = if malformed then null else meta.evaluator;
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

  measured =
    samples: side: builtins.filter (sample: sample.phase == "measure" && sample.side == side) samples;

  # a cell is rejected whole by any failed sample, a schedule that didn't run to
  # the end, or a projection that differs anywhere. the projection check only
  # runs once every sample has one, since it depends on them
  cell =
    samples:
    let
      expected = builtins.length schedule;
      shape = map (sample: { inherit (sample) phase side; }) samples;
      incomplete = lib.optional (
        shape != lib.take (builtins.length samples) schedule || builtins.length samples != expected
      ) "the schedule ran ${toString (builtins.length samples)} of ${toString expected} samples in order";
      failures = lib.concatMap (sample: sample.failures) samples ++ incomplete;
      projections = side: map (sample: sample.projection) (builtins.filter (s: s.side == side) samples);
      unstable = lib.concatMap (
        side:
        lib.optional (!allEqual (projections side)) "the ${side} projection differs between its samples"
      ) sides;
      mismatch = lib.optional (
        unstable == [ ] && builtins.head (projections "baseline") != builtins.head (projections "candidate")
      ) "the baseline and candidate projections differ";
      reasons = if failures != [ ] then failures else unstable ++ mismatch;
      baseline = measured samples "baseline";
      candidate = measured samples "candidate";
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
        inherit reasons;
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
    }:
    let
      samples = lib.concatMap (sizes: lib.concatLists (builtins.attrValues sizes)) (
        builtins.attrValues cells
      );
      reasons = refusal run samples;
    in
    if reasons != [ ] then
      {
        _tag = "refused";
        inherit reasons;
      }
    else
      {
        _tag = "compared";
        inherit run limits;
        cells = builtins.mapAttrs (_: builtins.mapAttrs (_: cell)) cells;
      };
in
{
  inherit
    schedule
    counters
    ownerOf
    sample
    cell
    compare
    median
    ;
  render = import ./render.nix { inherit lib counters; };
}
