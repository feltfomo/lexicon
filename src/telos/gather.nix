# the walked entries turned into the record the assembly reads. the assembly
# is handed declarations and knows nothing about files, so this is the one
# place a file becomes a declaration
{
  lib,
  fx,
  vocabulary,
  construct,
}:
let
  inherit (vocabulary) emit;

  # a file under a telos root is handed telos constructors and nothing else,
  # so a value that is not a declaration is a file that built something of
  # its own
  foreign =
    name:
    emit.malformed-declaration {
      at = [ name ];
      context = {
        what = "the outputs declared in ${name}";
        expected = "built with one of the output constructors";
      };
    };

  # one declaration is passed through as written, so a spec of the wrong
  # shape reaches the assembly and is refused in the words that already
  # exist for it
  merged =
    specs:
    if builtins.length specs == 1 then
      builtins.head specs
    else
      lib.zipAttrsWith (_: written: lib.foldl' (gathered: one: gathered // one) { } written) specs;

  # the merge above reduces one output name written twice to one attribute,
  # and both files are still in hand here, so the doubling is refused rather
  # than settled by whichever file the merge reached last
  doubling =
    held:
    let
      written = lib.concatMap (
        one:
        lib.optionals (builtins.isAttrs one.spec) (
          lib.concatMap (
            block:
            lib.optionals (builtins.isAttrs one.spec.${block}) (
              map (output: {
                inherit block output;
                inherit (one) origin;
              }) (builtins.attrNames one.spec.${block})
            )
          ) (builtins.attrNames one.spec)
        )
      ) held;
    in
    builtins.filter (group: builtins.length group > 1) (
      builtins.attrValues (lib.groupBy (each: "${each.block}/${each.output}") written)
    );

  doubled =
    at: declared: group:
    let
      one = builtins.head group;
    in
    emit.doubled-output-declaration {
      at = at ++ [
        one.block
        one.output
      ];
      context = {
        inherit (one) output;
        inherit declared;
        files = builtins.concatStringsSep " and " (lib.sort (a: b: a < b) (map (each: each.origin) group));
      };
    };

  # a refused name is dropped from the merge, so nothing downstream reads
  # whichever half the merge would have kept
  without =
    groups: spec:
    lib.mapAttrs (
      block: interior:
      builtins.removeAttrs interior (
        map (group: (builtins.head group).output) (
          builtins.filter (group: (builtins.head group).block == block) groups
        )
      )
    ) spec;

  gatheredFor =
    at: declared: held:
    let
      doubles = doubling held;
      whole = merged (map (one: one.spec) held);
    in
    fx.bind (fx.seq (map (doubled at declared) doubles)) (
      _: fx.pure (if doubles == [ ] then whole else without doubles whole)
    );

  byHost =
    grouped:
    builtins.foldl' (
      gathering: name:
      fx.bind gathering (
        got: fx.map (spec: got // { ${name} = spec; }) (gatheredFor [ "hosts" name ] name grouped.${name})
      )
    ) (fx.pure { }) (builtins.attrNames grouped);

  run =
    entries:
    let
      names = builtins.attrNames entries;
      declared = builtins.filter (name: construct.isSound entries.${name}) names;
      strange = builtins.filter (name: !construct.isSound entries.${name}) names;
      held = map (name: construct.read entries.${name}) declared;
      byKind = lib.groupBy (one: one.kind) held;
      hosts = byKind.host or [ ];
      fleet = byKind.fleet or [ ];
    in
    fx.bind (fx.seq (map foreign strange)) (
      _:
      fx.bind (byHost (lib.groupBy (one: one.source) hosts)) (
        gatheredHosts:
        fx.map (gatheredFleet: {
          hosts = gatheredHosts;
          fleet = gatheredFleet;
        }) (gatheredFor [ "fleet" ] "the fleet" fleet)
      )
    );
in
{
  inherit run;
}
