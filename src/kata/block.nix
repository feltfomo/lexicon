# what a block is. the contract a registry entry answers to, and the one place
# a diagnostic a block reported acquires the entry it came from
{
  lib,
  fx,
  krisis,
}:
let
  locationEffect = "kata/location";

  here = fx.send locationEffect null;

  # the location is installed for the validator's dynamic extent only, so an
  # effect the block sends for anything else rotates outward untouched
  within = prefix: comp: fx.effects.scope.val { ${locationEffect} = prefix; } comp;

  fields = [
    "name"
    "kinds"
    "before"
    "claimable"
    "codes"
    "validate"
    "compile"
  ];

  # a block declares codes as data and is never handed the reporter, so the
  # prefix reaches the path list before it is rendered
  vocabularyFor =
    block:
    let
      declared = krisis.vocabulary {
        namespace = "kata";
        source = block.name;
        inherit (block) codes;
      };
    in
    lib.mapAttrs (
      _: emitter: args:
      let
        given = if args == null then { } else args;
      in
      fx.bind here (prefix: emitter (given // { at = prefix ++ (given.at or [ ]); }))
    ) declared.emit;

  names = value: builtins.isList value && builtins.all builtins.isString value;

  problemsOf =
    kindNames: registered: block:
    let
      malformed = field: expected: {
        code = "malformed-registration";
        args = {
          at = [
            block.name
            field
          ];
          context = {
            inherit field expected;
            block = block.name;
          };
        };
      };

      unknownField =
        field:
        let
          problem = malformed field "a field this registry reads";
          nearest = krisis.suggest field fields;
        in
        problem
        // {
          args = problem.args // {
            notes = lib.optional (nearest != null) "did you mean '${nearest}'?";
          };
        };
    in
    map unknownField (builtins.filter (field: !builtins.elem field fields) (builtins.attrNames block))
    ++ lib.optional (!builtins.isFunction (block.validate or null)) (
      malformed "validate" "a computation of { emit, value }"
    )
    ++ lib.optional (
      !builtins.isFunction ((block.compile or { }).independent or null)
      || !builtins.isFunction ((block.compile or { }).dependent or null)
    ) (malformed "compile" "an independent half and a dependent half")
    ++ lib.optional (
      !builtins.isList (block.claimable or null) || !builtins.all names (block.claimable or [ ])
    ) (malformed "claimable" "a list of routes of field names")
    ++ lib.optional (!names (block.before or null)) (malformed "before" "a list of block names")
    ++ lib.optional (
      !names (block.kinds or null)
      || !builtins.all (kind: builtins.elem kind kindNames) (block.kinds or [ ])
    ) (malformed "kinds" "kinds this registry holds")
    ++ lib.concatMap (
      edge:
      lib.optional (!builtins.elem edge registered) {
        code = "unknown-block-edge";
        args = {
          at = [
            block.name
            "before"
          ];
          context = {
            block = block.name;
            inherit edge;
          };
          notes =
            let
              nearest = krisis.suggest edge registered;
            in
            lib.optional (nearest != null) "did you mean '${nearest}'?";
        };
      }
    ) (if names (block.before or null) then block.before else [ ]);
in
{
  inherit
    within
    vocabularyFor
    problemsOf
    ;
}
