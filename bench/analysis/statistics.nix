# admits the pinned evaluator's counted statistics before counters or source
# positions are used. malformed entries never reach attribution
{ lib }:
let
  natural = minimum: value: builtins.isInt value && value >= minimum;
  fields = [
    "nrOpUpdateValuesCopied"
    "nrFunctionCalls"
    "nrPrimOpCalls"
    "nrOpUpdates"
    "nrLookups"
    "nrAvoided"
    "nrThunks"
  ];
  function =
    entry:
    builtins.isAttrs entry
    && natural 1 (entry.count or null)
    && entry ? name
    && (entry.name == null || builtins.isString entry.name)
    && (
      let
        extra = builtins.attrNames (
          removeAttrs entry [
            "name"
            "count"
          ]
        );
      in
      extra == [ ]
      || (
        (
          extra == [
            "column"
            "line"
          ]
          ||
            extra == [
              "column"
              "file"
              "line"
            ]
        )
        && natural 1 entry.line
        && natural 0 entry.column
        && (!(entry ? file) || (builtins.isString entry.file && entry.file != ""))
      )
    );
  sum = builtins.foldl' (total: value: total + value) 0;
in
stats:
if !builtins.isAttrs stats then
  [ "statistics are not an object" ]
else
  let
    functions = stats.functions or null;
    primops = stats.primops or null;
    validFunctions = builtins.isList functions && builtins.all function functions;
    validPrimops = builtins.isAttrs primops && builtins.all (natural 1) (builtins.attrValues primops);
    invalidCounters = builtins.filter (name: !(natural 0 (stats.${name} or null))) fields;
    validTotal = name: natural 0 (stats.${name} or null);
    categories = [
      "values"
      "envs"
      "sets"
      "list"
    ];
    invalidAllocations = builtins.filter (
      name:
      let
        value = stats.${name} or null;
      in
      !builtins.isAttrs value
      || !builtins.all (field: natural 0 (value.${field} or null)) (
        if name == "list" then
          [
            "elements"
            "concats"
            "bytes"
          ]
        else
          [
            "number"
            "bytes"
          ]
      )
    ) categories;
  in
  lib.optional (!(stats ? functions && stats ? primops)) "has statistics without call counts"
  ++ lib.optional (
    (stats.attributes or "missing") != null
  ) "attribute selections differ from the qualified evaluator"
  ++ lib.optional (
    invalidCounters != [ ]
  ) "statistics lack natural counters ${lib.concatStringsSep ", " invalidCounters}"
  ++ lib.optional (
    invalidAllocations != [ ]
  ) "statistics have malformed allocations ${lib.concatStringsSep ", " invalidAllocations}"
  ++ lib.optional (!validFunctions) "function count entries are malformed"
  ++ lib.optional (!validPrimops) "primop counts are malformed"
  ++ lib.optional (validFunctions && functions == [ ]) "statistics count no function applications"
  ++ lib.optional (
    validFunctions
    && validTotal "nrFunctionCalls"
    && sum (map (entry: entry.count) functions) != stats.nrFunctionCalls
  ) "function counts do not sum to nrFunctionCalls"
  ++ lib.optional (
    validPrimops
    && validTotal "nrPrimOpCalls"
    && sum (builtins.attrValues primops) != stats.nrPrimOpCalls
  ) "primop counts do not sum to nrPrimOpCalls"
