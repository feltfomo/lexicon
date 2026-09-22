# emission. a caller hands the door capabilities, a backend declares the keys
# of the ones it applies, and a backend short of a key it declared reaches no
# host
{
  lib,
  fx,
  krisis,
  arrows,
  t,
  blocks,
  construct,
  claimKeys,
  knownNames,
  Prepared,
  text,
}:
let
  vocabulary = import ./vocabulary.nix { inherit krisis text; };

  types = import ./types.nix { inherit fx t; };

  placement = import ./placement.nix;

  compile = import ./compile.nix {
    inherit
      lib
      t
      arrows
      blocks
      placement
      ;
  };

  registered = import ./backends { inherit lib krisis types; };

  inherit (vocabulary) emit;
  inherit (arrows) sum traverse;
  inherit (fx) pipeline;

  gathered = pairs: lib.listToAttrs (lib.concatLists pairs);

  malformed =
    at: what: expected:
    emit.malformed-emission {
      inherit at;
      context = {
        inherit what expected;
      };
    };

  Handed = sum {
    prepared = t.Attrs;
    foreign = t.Any;
  };

  handedOf =
    value: if Prepared.check value then Handed.inject.prepared value else Handed.inject.foreign value;

  # the three ways a key a backend declared can arrive
  Supply = sum {
    supplied = t.Attrs;
    malformed = t.Attrs;
    absent = t.Attrs;
  };

  supplyOf =
    handed: backend: need:
    let
      asked = {
        inherit need;
        backend = backend.name;
      };
    in
    if !(handed ? ${need}) then
      Supply.inject.absent asked
    else if !types.Capability.check handed.${need} then
      Supply.inject.malformed asked
    else
      Supply.inject.supplied (asked // { capability = handed.${need}; });

  # the join is the same classification as the leaf
  Provision = sum {
    ready = t.Attrs;
    short = t.Attrs;
  };

  withCapability =
    asked: provision:
    Provision.case {
      ready =
        held:
        Provision.inject.ready (
          held
          // {
            handed = held.handed // {
              ${asked.need} = asked.capability;
            };
          }
        );
      short = Provision.inject.short;
    } provision;

  withoutCapability =
    provision:
    Provision.case {
      ready = held: Provision.inject.short { inherit (held) backend; };
      short = Provision.inject.short;
    } provision;

  # each need is classified where it arrives and each arm sends its own
  # report
  weigh =
    handed: backend:
    fx.pipe
      (fx.pure (
        Provision.inject.ready {
          inherit backend;
          handed = { };
        }
      ))
      (
        map (
          need: provision:
          Supply.case {
            supplied = asked: fx.pure (withCapability asked provision);

            malformed =
              asked:
              fx.bind (emit.malformed-capability {
                at = [
                  asked.backend
                  asked.need
                ];
                context = {
                  capability = asked.need;
                };
              }) (_: fx.pure (withoutCapability provision));

            absent =
              asked:
              fx.bind (emit.missing-capability {
                at = [
                  asked.backend
                  asked.need
                ];
                context = {
                  inherit (asked) backend;
                  capability = asked.need;
                };
              }) (_: fx.pure (withoutCapability provision));
          } (supplyOf handed backend need)
        ) backend.needs
      );

  # a facet that claims no host is narrowed by nothing
  Reach = sum {
    everywhere = t.Attrs;
    claimed = t.Attrs;
  };

  reachOf =
    claim: if claim.hosts == [ ] then Reach.inject.everywhere claim else Reach.inject.claimed claim;

  # the arms decide what is carried. the users half of a claim narrows which
  # user a facet reaches, and this tree places no user, so nothing here
  # reads it and a facet reaches every user of a host it reaches
  carriedFor =
    host: pair: claim:
    Reach.case {
      everywhere = _: [ pair ];
      claimed = held: lib.optional (builtins.elem host.name held.hosts) pair;
    } (reachOf claim);

  # the claims the door was handed either cover the block in hand or they do
  # not, and a name one holds is certified against the registry beside it
  Claiming = sum {
    resolved = t.Attrs;
    absent = t.Attrs;
    uncertifiable = t.Attrs;
  };

  claimingOf =
    certified: entry: block: claim:
    let
      sat = { inherit entry block; };
    in
    if claim == null then
      Claiming.inject.absent sat
    else if certified.check claim.hosts then
      Claiming.inject.resolved { inherit claim; }
    else
      Claiming.inject.uncertifiable sat;

  interiorsFor =
    certified: claims: host: entry:
    fx.map gathered (
      traverse (
        name:
        blocks.Registration.case {
          known =
            block:
            Claiming.case {
              resolved =
                seen: fx.pure (carriedFor host (lib.nameValuePair block entry.blocks.${block}) seen.claim);

              absent =
                seen:
                fx.bind
                  (malformed [
                    seen.entry
                    seen.block
                  ] "the claims beside the registry" "wide enough to cover ${seen.block} in ${seen.entry}")
                  (_: fx.pure [ ]);

              uncertifiable =
                seen:
                fx.bind
                  (malformed [
                    seen.entry
                    seen.block
                  ] "the claim on ${seen.block} in ${seen.entry}" "a list of names the registry holds")
                  (_: fx.pure [ ]);
            } (claimingOf certified entry.name block (claims.${entry.name}.${block} or null));

          unregistered = _: fx.pure [ ];
        } (blocks.classify name)
      ) (builtins.attrNames entry.blocks)
    );

  entriesFor =
    certified: environment: host:
    fx.map (entries: builtins.filter (entry: entry.interiors != { }) entries) (
      traverse (
        entry:
        fx.map (interiors: {
          inherit (entry) name;
          inherit interiors;
        }) (interiorsFor certified environment.prepared.claims host entry)
      ) environment.prepared.registry.entries
    );

  # what a backend hands back is read for shape before it is carried
  Emitted = sum {
    target = t.Attrs;
    malformed = t.Attrs;
  };

  emittedOf =
    backend: host: produced:
    if types.Target.check produced then
      Emitted.inject.target { inherit host produced; }
    else
      Emitted.inject.malformed { inherit backend host; };

  # the names a claim may hold are the registry's own, read once for the
  # whole walk
  targetsFor =
    environment: ready:
    let
      certified = knownNames (map (one: one.name) environment.prepared.registry.hosts);
    in
    fx.map gathered (
      traverse (
        host:
        fx.bind (entriesFor certified environment host) (
          entries:
          Emitted.case
            {
              target = held: fx.pure [ (lib.nameValuePair held.host.name held.produced) ];

              malformed =
                held:
                fx.bind (malformed
                  [
                    held.backend
                    held.host.name
                  ]
                  "what backend ${held.backend} emits for ${held.host.name}"
                  "a target carrying a host, its modules, the carried blocks and what was built"
                ) (_: fx.pure [ ]);
            }
            (
              emittedOf ready.backend.name host (
                ready.backend.emit {
                  inherit (ready) handed;
                  inherit host entries;

                  # the backend decides what it binds, so the module that
                  # carries the binding is built where that decision is
                  inherit (compile) bindings;

                  project =
                    {
                      bound,
                      interiors,
                    }:
                    compile.project {
                      inherit (ready.backend) context;
                      inherit bound interiors;
                    };
                }
              )
            )
        )
      ) environment.prepared.registry.hosts
    );

  registrationStage = pipeline.mkStage {
    name = "backend-registry-check";
    transform =
      _:
      pipeline.bind (pipeline.asks (environment: environment.backends)) (
        backends:
        pipeline.bind (fx.seq (map (problem: emit.${problem.code} problem.args) backends.problems)) (
          _: pipeline.pure null
        )
      );
  };

  supplyStage = pipeline.mkStage {
    name = "capability-supply";
    transform =
      _:
      pipeline.bind pipeline.ask (
        environment: traverse (weigh environment.capabilities) environment.backends.entries
      );
  };

  emitStage = pipeline.mkStage {
    name = "emit";
    transform =
      provisioned:
      pipeline.bind pipeline.ask (
        environment:
        fx.map gathered (
          traverse (Provision.case {
            ready =
              held:
              fx.map (targets: [ (lib.nameValuePair held.backend.name targets) ]) (targetsFor environment held);

            short = _: fx.pure [ ];
          }) provisioned
        )
      );
  };

  stages = [
    registrationStage
    supplyStage
    emitStage
  ];

  run =
    {
      policy ? krisis.policy.collect,
      rendering ? krisis.rendering.default,
      capabilities ? { },
      backends ? registered,
    }:
    value:
    krisis.run { inherit policy rendering; } (
      krisis.gate (
        Handed.case {
          prepared =
            held:
            fx.effects.scope.run {
              handlers = fx.effects.reader.handler;
              state = {
                prepared = held;
                inherit capabilities backends;
              };
            } (pipeline.compose stages null);

          foreign =
            _:
            fx.bind (malformed [ ] "what the door was handed" "a registry and the claims resolved against it") (
              _: fx.pure { }
            );
        } (handedOf value)
      )
    );

  aspectFor =
    backend:
    import ./aspect.nix {
      inherit
        lib
        fx
        krisis
        vocabulary
        compile
        construct
        claimKeys
        ;
      inherit (backend) context;
    };
in
{
  inherit
    run
    aspectFor
    types
    vocabulary
    ;

  backends = registered;

  internal = {
    inherit compile placement;
  };
}
