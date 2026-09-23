# the declaration layer. constructors hand back inert values, the fold is
# a kleisli arrow onto a plain declaration, and the layer below arrives as
# an argument so nothing here names where it lives
{
  lib,
  fx,
  krisis,
  engine,
  arrows,
  walk,
}:
let
  kinds = import ./kinds.nix { };
  vocabulary = import ./vocabulary.nix {
    inherit krisis;
    inherit (walk) codes;
  };

  claims = import ./claims.nix {
    inherit
      lib
      fx
      vocabulary
      kinds
      ;
  };

  block = import ./block.nix { inherit lib fx krisis; };

  blocks = import ./blocks {
    inherit
      lib
      fx
      arrows
      krisis
      block
      kinds
      vocabulary
      ;
    inherit (engine) t;
    claimKeys = claims.keys;
  };

  # the types are built off the instance's own t, so anything kata ever
  # hands the layer below carries that instance's stamp
  types = import ./types.nix {
    inherit fx;
    inherit (engine) t;
    walk = walk.types;
  };

  construct = import ./construct.nix { inherit lib kinds types; };

  settings = import ./settings.nix { inherit (engine) t; };

  # composition reads the kind registry to decide where an included value
  # lands, and the registry arrives here the way every other slice of it does
  compose = import ./compose.nix {
    inherit
      lib
      fx
      arrows
      vocabulary
      construct
      kinds
      ;
    inherit (engine) t;
  };

  fold = import ./fold.nix {
    inherit
      lib
      fx
      krisis
      arrows
      kinds
      blocks
      claims
      block
      vocabulary
      construct
      types
      ;
  };

  resolve = import ./resolve.nix {
    inherit
      lib
      fx
      krisis
      arrows
      vocabulary
      claims
      blocks
      kinds
      types
      ;
    inherit (engine) t;
  };

  # the one widening. a kind whose schema is not already held arrives
  # through the contribution argument and nowhere else
  contribution = instance: {
    kinds = map (kind: {
      inherit (kind) name collection;
      fields = kind.fields instance.t;
    }) (builtins.filter (kind: kind.fields != null) kinds);
  };

  # the layer below opens its own run, so its diagnostics are replayed
  # outward here and the caller's policy sees one stream. the places die
  # here, and what comes back up beside the registry is the resolved claims,
  # which is everything emission is handed
  handDown =
    rendering: contributions: settled:
    let
      outcome = engine.run {
        policy = krisis.policy.collect;
        inherit rendering;
        # the caller's list keeps the positions the caller wrote, so a
        # diagnostic naming one of them names it as the caller counted
        contributions = contributions ++ [ contribution ];
      } settled.declaration;
    in
    fx.bind (krisis.reportAll outcome.diagnostics) (
      _:
      fx.pure {
        registry = outcome.value;
        inherit (settled) claims;
      }
    );

  # the declaration view stops before resolution, because a claim naming a
  # host is a question about a fleet and this view is handed one file's worth
  check =
    {
      policy ? krisis.policy.collect,
      rendering ? krisis.rendering.default,
      strict ? false,
    }:
    values:
    krisis.run { inherit policy rendering; } (
      fx.pipe (compose.flatten values) [
        (fold.run strict)
        (indexed: fx.pure indexed.declaration)
      ]
    );

  # four arrows, composed. an includes list is followed before the fold sees
  # anything, the fold's gate halts before the rest run, and resolution has
  # the places in hand while the layer below never does
  run =
    {
      policy ? krisis.policy.collect,
      rendering ? krisis.rendering.default,
      strict ? false,
      contributions ? [ ],
    }:
    values:
    krisis.run { inherit policy rendering; } (
      fx.pipe (compose.flatten values) [
        (fold.run strict)
        resolve.run
        (handDown rendering contributions)
      ]
    );

  load = run { };

  # the seam, read without a policy. composition still runs, so a value that
  # reaches a declaration only through an includes list reaches this view too
  declarationOf =
    values:
    (krisis.run { } (
      fx.map (indexed: indexed.declaration) (fx.bind (compose.flatten values) (fold.run false))
    )).value;
in
construct.from null
// {
  inherit
    load
    run
    check
    contribution
    settings
    ;

  # a file the walk read stamps its constructors, so every value it builds
  # says where it came from
  inherit (construct) from;

  internal = {
    inherit
      kinds
      blocks
      block
      types
      vocabulary
      claims
      ;
    inherit declarationOf;
    inherit (compose) flatten;
    inherit resolve construct;
  };
}
