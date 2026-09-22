# the identity registry. a declaration goes in, a frozen queryable registry
# comes out, and every problem in the declaration is reported in one pass
{
  lib,
  fx,
  krisis,
}:
let
  # minted here, once per instance, and nowhere else
  token = import ./token.nix { };

  types = import ./types.nix { inherit fx token; };
  field = import ./field.nix { inherit lib; };
  vocabulary = import ./vocabulary.nix { inherit krisis; };
  accessors = import ./accessors.nix { inherit lib; };
  order = import ./order.nix {
    inherit
      lib
      types
      field
      accessors
      ;
  };
  bridge = import ./bridge.nix { inherit lib vocabulary; };
  query = import ./query.nix {
    inherit
      lib
      fx
      vocabulary
      accessors
      ;
  };
  checks = import ./checks.nix { inherit lib; };

  core = import ./kinds.nix {
    inherit lib field;
    inherit (types) t;
  };

  sources = import ./sources { inherit lib krisis; };

  retired = import ./retired.nix { inherit lib; };

  declare = import ./phases/declare.nix {
    inherit
      lib
      krisis
      sources
      retired
      ;
  };
  normalize = import ./phases/normalize.nix { inherit lib field; };
  validate = import ./phases/validate.nix {
    inherit
      lib
      fx
      krisis
      types
      vocabulary
      bridge
      ;
  };
  freeze = import ./phases/freeze.nix { inherit query; };

  inherit (order) resolveKinds;

  # everything a contribution may add. a contribution widens the schema and
  # never re-opens the declaration surface
  contributionKeys = [
    "kinds"
    "fields"
    "requirements"
    "checks"
  ];

  # a key the door itself reads, handed back by a contribution. nesting a
  # contribution inside a contribution is not implemented
  reservedKeys = [
    "contributions"
    "sources"
  ];

  invalidValue = at: name: expected: value: notes: {
    code = "invalid-value";
    args = {
      inherit at notes;
      context = {
        field = name;
        type = expected;
        inherit value;
      };
    };
  };

  # what a contribution hands back is read as closely as a declaration is.
  # a key nobody reads would otherwise be a silent no-op
  keyProblems =
    at: produced:
    lib.concatMap (
      key:
      let
        value = produced.${key};
        listed = key == "kinds" || key == "checks";
        wanted = if listed then "a list" else "an attrset of lists keyed by kind";
        wellTyped = if listed then builtins.isList value else builtins.isAttrs value;
      in
      if builtins.elem key contributionKeys then
        if !wellTyped then
          [ (invalidValue (at ++ [ key ]) key wanted value [ ]) ]
        else if listed then
          [ ]
        else
          # a kind whose entry is not a list of its own is dropped by the
          # merge, so the shape is read one level down as well
          lib.concatMap (
            inner:
            lib.optional (!builtins.isList value.${inner}) (
              invalidValue (
                at
                ++ [
                  key
                  inner
                ]
              ) inner "a list of ${key} for kind ${inner}" value.${inner} [ ]
            )
          ) (builtins.attrNames value)
      else if builtins.elem key reservedKeys then
        [
          {
            code = "unimplemented-key";
            args = {
              inherit at;
              context = {
                inherit key;
              };
            };
          }
        ]
      else
        [
          {
            code = "unknown-field";
            args = {
              at = at ++ [ key ];
              context = {
                field = key;
              };
              notes =
                let
                  nearest = krisis.suggest key contributionKeys;
                in
                lib.optional (nearest != null) "did you mean '${nearest}'?" ++ retired.noteFor key;
            };
          }
        ]
    ) (builtins.attrNames produced);

  # every contribution reaches the fold through the one argument at the
  # door and is applied the same way, so there is a single stream here and
  # where a contributed field lands is decided by list order, then by that
  # contribution's own field list order, then by the field name as the last
  # tiebreak
  gather =
    instance: contributions:
    let
      listed = if builtins.isList contributions then contributions else [ ];

      # one contribution written without the list around it reaches nothing
      shapeProblems = lib.optional (!builtins.isList contributions) (
        invalidValue [
          "contributions"
        ] "contributions" "a list of functions of the instance" contributions [ ]
      );

      apply =
        position: entry:
        let
          at = [
            "contributions"
            position
          ];

          attempt = builtins.tryEval (
            let
              produced = entry instance;
            in
            if builtins.isAttrs produced then
              builtins.deepSeq (builtins.attrNames produced) produced
            else
              produced
          );
        in
        if !builtins.isFunction entry then
          {
            value = { };
            problems = [ (invalidValue at "contributions" "a function of the instance" entry [ ]) ];
          }
        else if !attempt.success then
          {
            value = { };
            problems = [
              (invalidValue at "contributions" "a function of the instance" null [
                "applying the contribution threw"
              ])
            ];
          }
        else if !builtins.isAttrs attempt.value then
          {
            value = { };
            problems = [
              (invalidValue at "contributions" "an attrset of contributions" attempt.value [ ])
            ];
          }
        else
          {
            inherit (attempt) value;
            problems = keyProblems at attempt.value;
          };

      positioned = lib.imap0 (index: entry: apply index entry // { inherit index; }) listed;

      listFrom =
        offer: key:
        let
          value = offer.value.${key} or [ ];
        in
        if builtins.isList value then value else [ ];

      attrsFrom =
        offer: key:
        let
          value = offer.value.${key} or { };
        in
        if builtins.isAttrs value then
          lib.mapAttrs (_: held: if builtins.isList held then held else [ ]) value
        else
          { };

      # a contributed field spec carries the position it came from and its
      # place in that contribution's own list, and the resolver sorts on
      # the two rather than on however the attrsets happened to merge
      fieldsFrom =
        offer:
        lib.mapAttrs (
          _: specs:
          lib.imap0 (
            place: spec:
            spec
            // {
              order = place;
              inherit (offer) index;
            }
          ) specs
        ) (attrsFrom offer "fields");

      mergeKeyed =
        selector:
        lib.foldl' (
          accumulated: offer:
          accumulated // lib.mapAttrs (name: added: (accumulated.${name} or [ ]) ++ added) (selector offer)
        ) { } positioned;
    in
    {
      kinds = lib.concatMap (offer: listFrom offer "kinds") positioned;
      checks = lib.concatMap (offer: listFrom offer "checks") positioned;
      fields = mergeKeyed fieldsFrom;
      requirements = mergeKeyed (offer: attrsFrom offer "requirements");
      problems = shapeProblems ++ lib.concatMap (offer: offer.problems) positioned;
    };

  # four phases, strict order, and no phase doing another's job
  pipeline =
    instance: contributions: declaration:
    let
      extension = gather instance contributions;

      resolved = resolveKinds {
        kinds = core ++ extension.kinds;
        inherit (extension) fields requirements;
      };

      declared = declare.run { inherit (resolved) kinds; } declaration;
      normalized = normalize.run { inherit (resolved) kinds; } declared.entries;
    in
    fx.map
      (
        registry:
        freeze.run {
          inherit (resolved) kinds;
          inherit (normalized) provenance;
          inherit registry;
        }
      )
      (
        validate.run {
          inherit (resolved) kinds;
          inherit (normalized) provenance;
          inherit (extension) checks;
          problems = extension.problems ++ resolved.problems ++ declared.problems ++ normalized.notices;
        } normalized.registry
      );

  run =
    {
      policy ? krisis.policy.collect,
      rendering ? krisis.rendering.default,
      contributions ? [ ],
    }:
    declaration:
    let
      outcome = krisis.run { inherit policy rendering; } (pipeline self contributions declaration);
    in
    outcome
    // {
      value =
        if outcome.value == null then null else outcome.value.withDiagnostics (outcome.diagnostics or [ ]);
    };

  load = run { };

  check = declaration: builtins.removeAttrs (run { } declaration) [ "value" ];

  explain = run { policy = krisis.policy.pretty { long = true; }; };

  rendered =
    diagnostic:
    "${diagnostic.severity}: ${diagnostic.code}${
      lib.optionalString (diagnostic.at != null) " at ${diagnostic.at}"
    }: ${diagnostic.message}";

  orThrow =
    outcome:
    if outcome.hasErrors then
      throw (outcome.report or (lib.concatStringsSep "\n" (map rendered (outcome.diagnostics or [ ]))))
    else
      outcome.value;

  # the one public attrset, and the exact value handed to every
  # contribution, so a type a contribution builds carries this instance's
  # token and never reads as foreign
  self = {
    inherit
      load
      check
      checks
      explain
      run
      orThrow
      ;

    inherit (types) t;

    # the door takes a policy and a rendering as well as a declaration
    inherit (krisis) policy rendering;

    # a named source, built once and written into the sources key
    source = {
      inherit (sources) den;
    };

    internal = {
      inherit resolveKinds vocabulary accessors;
      kinds = core;
      phases = {
        inherit
          declare
          normalize
          validate
          freeze
          ;
      };
    };
  };
in
self
