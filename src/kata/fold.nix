# the fold is a pipeline. each phase is a named stage that reports while it
# walks and narrows what it hands on, and what leaves the far end is a
# declaration that could have been hand-written
{
  lib,
  fx,
  krisis,
  arrows,
  kinds,
  blocks,
  claims,
  block,
  vocabulary,
  construct,
  types,
}:
let
  inherit (vocabulary) emit;
  inherit (arrows) sum;
  inherit (fx) pipeline;

  # the kind registry, the block registry, the caller's strictness and the
  # places composition decided on are the environment the stages read. origin
  # differs per value and travels on the value
  environment = strict: placements: {
    inherit
      kinds
      blocks
      strict
      placements
      ;
  };

  kindNamed = registry: name: lib.findFirst (kind: kind.name == name) null registry;

  wrapperKeys = [
    "declare"
    "includes"
  ];

  # a value the walker read and a value built inline are placed differently,
  # and which one is in hand is decided here and nowhere below
  Stamp = sum {
    walked = types.Relative;
    inline = types.Name;
  };

  stampOf =
    name: held:
    if held.origin == null then Stamp.inject.inline name else Stamp.inject.walked held.origin;

  # a diagnostic names the file the value came from, and a value that came
  # from no file is named by the key it was written under
  where =
    name: held:
    Stamp.case {
      walked = origin: [ origin ];
      inline = written: [ written ];
    } (stampOf name held);

  malformed = at: what: expected: notes: {
    inherit at notes;
    context = {
      inherit what expected;
    };
  };

  # fx hands over a flat failure record carrying a Position list, the same
  # shape the registry's own bridge reads. as of nix-effects 55ec2657 only
  # Field positions can happen under a record of scalars, and anything else
  # is reported
  segmentOf =
    position: if (position.tag or null) == "Field" && position ? name then position.name else null;

  blameOf =
    name: held: failure:
    let
      parts = map segmentOf (failure.path or [ ]);
      mapped = parts != [ ] && builtins.all (part: part != null) parts;
      at = where name held ++ lib.optionals mapped parts;
    in
    emit.malformed-construction (
      malformed at (if mapped then lib.last parts else name) (failure.typeName or "?") (
        lib.optional (!mapped) "reason: ${toString (failure.reason or "unknown")}"
      )
    );

  # the payload's shape is decided by its type, and each failure comes back
  # blaming the field that produced it
  shapeOf =
    name: value:
    if !construct.isTagged value then
      emit.malformed-construction (malformed [ name ] name "built with one of kata's constructors" [ ])
    else
      let
        held = construct.read value;
      in
      fx.bind (fx.effects.scope.runWith {
        handlers = fx.effects.typecheck.collecting;
        state = [ ];
      } (types.Payload.validate held)) (checked: fx.seq (map (blameOf name held) checked.state));

  shapeStage = pipeline.mkStage {
    name = "construct-shape";
    transform =
      values:
      pipeline.bind (fx.seq (lib.mapAttrsToList shapeOf values)) (
        _: pipeline.pure (lib.filterAttrs (_: construct.isSound) values)
      );
  };

  # a registration defect belongs to the registry, and it is reported on the
  # same stream so a caller has one place to read
  registryStage = pipeline.mkStage {
    name = "registry-check";
    transform =
      values:
      pipeline.bind (pipeline.asks (env: env.blocks)) (
        registry:
        pipeline.bind (fx.seq (map (problem: emit.${problem.code} problem.args) registry.problems)) (
          _: pipeline.pure values
        )
      );
  };

  unknownKind =
    registry: item:
    emit.unknown-kind {
      at = where item.name item.held;
      context = {
        inherit (item.held) kind;
      };
      notes =
        let
          nearest = krisis.suggest item.held.kind (map (kind: kind.name) registry);
        in
        lib.optional (nearest != null) "did you mean '${nearest}'?";
    };

  resolveStage = pipeline.mkStage {
    name = "kind-resolve";
    transform =
      values:
      pipeline.bind (pipeline.asks (env: env.kinds)) (
        registry:
        let
          resolved = lib.mapAttrsToList (
            name: value:
            let
              held = construct.read value;
            in
            {
              inherit name held;
              described = kindNamed registry held.kind;
            }
          ) values;
        in
        pipeline.bind (fx.seq (
          map (unknownKind registry) (builtins.filter (item: item.described == null) resolved)
        )) (_: pipeline.pure (builtins.filter (item: item.described != null) resolved))
      );
  };

  unknownBlock =
    registry: strict: at: name:
    emit.unknown-block {
      at = at ++ [ name ];
      severity = if strict then "error" else "warning";
      context = {
        block = name;
      };
      notes =
        let
          nearest = krisis.suggest name registry.names;
        in
        lib.optional (nearest != null) "did you mean '${nearest}'?";
    };

  disallowedBlock =
    allowed: item: at: name:
    emit.disallowed-block {
      at = at ++ [ name ];
      context = {
        inherit (item.held) kind;
        block = name;
      };
      notes =
        let
          nearest = krisis.suggest name allowed;
        in
        lib.optional (nearest != null) "did you mean '${nearest}'?";
    };

  # the interior belongs to the block, and the entry it sits in is installed
  # for the validator's extent so a diagnostic it reports is placed without
  # anyone touching a rendered one
  delegate =
    registry: item: at: name:
    let
      held = registry.byName.${name};
      value = item.held.blocks.${name};
      prefix = at ++ [ name ];
    in
    fx.bind
      (block.within prefix (
        held.validate {
          emit = registry.emitters.${name};
          inherit value;
        }
      ))
      (
        _:
        claims.check {
          block = held;
          inherit value;
          at = prefix;
        }
      );

  blocksOf =
    registry: strict: item:
    let
      allowed = registry.allowedIn item.described.name;
      at = where item.name item.held;
      present = builtins.attrNames item.held.blocks;

      unregistered = builtins.filter (name: !registry.has name) present;
      misplaced = builtins.filter (name: registry.has name && !builtins.elem name allowed) present;
      legal = builtins.filter (name: builtins.elem name allowed) present;

      # a declare-bearing kind takes two keys and nothing else. spec is Any
      # so the reporter can name whatever the caller wrote, which leaves
      # these keys to be checked here
      stray = lib.optionals item.described.declare (
        builtins.filter (key: !builtins.elem key wrapperKeys) (
          builtins.attrNames (if builtins.isAttrs item.held.spec then item.held.spec else { })
        )
      );

      # a stray key that names a registered block is a block written onto a
      # kind that carries none, and it is reported as the placement it is
      strayBlocks = builtins.filter registry.has stray;
      strayKeys = builtins.filter (key: !registry.has key) stray;
    in
    fx.seq (
      map (unknownBlock registry strict at) unregistered
      ++ map (disallowedBlock allowed item at) (misplaced ++ strayBlocks)
      ++ map (
        key: emit.malformed-construction (malformed (at ++ [ key ]) key "either declare or includes" [ ])
      ) strayKeys
      ++ map (delegate registry item at) legal
    );

  blockStage = pipeline.mkStage {
    name = "block-check";
    transform =
      items:
      pipeline.bind (pipeline.asks (env: env.blocks)) (
        registry:
        pipeline.bind (pipeline.asks (env: env.strict)) (
          strict: pipeline.bind (fx.seq (map (blocksOf registry strict) items)) (_: pipeline.pure items)
        )
      );
  };

  # a declare is unwrapped into the fields the entity kind already holds,
  # and a kind without one lands as its blocks
  payloadOf =
    item: if item.described.declare then item.held.declare else { inherit (item.held) blocks; };

  # composition decided where each payload is written and how many times, so
  # this walk writes what it was handed and decides nothing
  collected =
    placements: items:
    lib.foldl' (
      accumulated: item:
      lib.foldl' (
        gathered: path: lib.recursiveUpdate gathered (lib.setAttrByPath path (payloadOf item))
      ) accumulated (placements.${item.name} or [ ])
    ) { } items;

  # the place each declaration is diagnosed at, keyed by the name it landed
  # under. it rides beside the declaration because origin is stamped by the
  # walk and is never a field a caller may write
  placed =
    items: lib.listToAttrs (map (item: lib.nameValuePair item.name (where item.name item.held)) items);

  placeStage = pipeline.mkStage {
    name = "place";
    transform =
      items:
      pipeline.bind (pipeline.asks (env: env.placements)) (
        placements:
        pipeline.pure {
          declaration = collected placements items;
          origins = placed items;
        }
      );
  };

  stages = [
    registryStage
    shapeStage
    resolveStage
    blockStage
    placeStage
  ];

  # the environment is installed for the walk only, so the krisis effects
  # the stages send rotate outward to whatever policy the caller opened
  walk =
    strict: composed:
    fx.effects.scope.run {
      handlers = fx.effects.reader.handler;
      state = environment strict composed.placements;
    } (pipeline.compose stages composed.values);

  # the gate is what forces validation onto the output path, so a
  # declaration is never built out of values nobody read. what leaves here
  # is a declaration and the places its parts are diagnosed at, which is the
  # only shape claim resolution accepts
  run =
    strict: composed:
    krisis.gate (
      if builtins.isAttrs composed.values then
        walk strict composed
      else
        fx.bind
          (emit.malformed-construction (malformed [ ] "a declaration" "an attrset of constructed values" [ ]))
          (
            _:
            fx.pure {
              declaration = { };
              origins = { };
            }
          )
    );
in
{
  inherit run;
}
