# judges what each observation cell printed. a fixture callback traces
# `<prefix> <event>` when it runs, so its stderr shows how often and in which
# order callbacks ran and which error contexts wrapped a failure, none of which
# a value can show. failures accumulate across every cell before the law throws
{
  lib,
  families,
  dir,
}:
let
  judge =
    family: spec: path: expect:
    let
      base = "${dir}/${family}/${path}";
      stderr = builtins.readFile "${base}.stderr";
      exit = lib.toInt (lib.removeSuffix "\n" (builtins.readFile "${base}.exit"));
      events = lib.concatMap (
        line:
        let
          matched = builtins.match "trace: ${lib.escapeRegex spec.prefix} (.*)" line;
        in
        lib.optional (matched != null) (builtins.head matched)
      ) (lib.splitString "\n" stderr);
      named = "${family} ${path}";
      fails = expect.fails or false;
      ordered = expect.ordered or null;
      kept = builtins.filter (
        event: builtins.any (prefix: lib.hasPrefix prefix event) ordered.prefixes
      ) events;
    in
    lib.optional (fails && exit == 0) "${named} succeeded but should fail"
    ++ lib.optional (!fails && exit != 0) "${named} exited ${toString exit}"
    ++ lib.concatLists (
      lib.mapAttrsToList (
        event: count:
        let
          seen = lib.count (other: other == event) events;
        in
        lib.optional (
          seen != count
        ) "${named} traced ${event} ${toString seen} times, expected ${toString count}"
      ) (expect.counts or { })
    )
    ++
      lib.optional (ordered != null && kept != ordered.events)
        "${named} ran ${lib.concatStringsSep ", " kept}, expected ${lib.concatStringsSep ", " ordered.events}"
    ++
      lib.optional (expect ? sequence && events != expect.sequence)
        "${named} traced [${lib.concatStringsSep ", " events}], expected [${lib.concatStringsSep ", " expect.sequence}]"
    ++ map (context: "${named} lacks the context ${context}") (
      builtins.filter (context: !lib.hasInfix context stderr) (expect.context or [ ])
    );

  failures = lib.concatLists (
    lib.mapAttrsToList (
      family: spec: lib.concatLists (lib.mapAttrsToList (judge family spec) spec.cells)
    ) families
  );
in
if failures == [ ] then
  lib.mapAttrs (_: spec: builtins.length (builtins.attrNames spec.cells)) families
else
  throw "observation events failed\n${
    lib.concatMapStringsSep "\n" (failure: "- ${failure}") failures
  }"
