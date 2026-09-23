# a check is the description of a build, never a built artifact. a derivation
# cannot be held by a kernel checked record, so what this block validates is
# the build steps, which are plain data, and the derivation is made in the
# dependent half where a package set is in hand
{ lib, fx, ... }:
let
  # the pair fx.build requires of a step at nix-effects 0.16.0. the step type
  # is an open record there, so a field this block does not read is left for
  # that layer rather than refused here
  isStep =
    value:
    builtins.isAttrs value
    && builtins.isString (value.name or null)
    && builtins.isString (value.run or null);

  declaredOf = value: if builtins.isAttrs value then value else { };

  stepsOf = declared: if builtins.isList (declared.steps or null) then declared.steps else [ ];

  planFor =
    name: steps:
    fx.build.plan {
      inherit name steps;
    };
in
{
  name = "checks";

  kinds = [
    "host"
    "fleet"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    checks-interior = {
      message = "a checks block must be an attrset of declared checks";
      help = "write the block as an attrset keyed by the name each check takes in the flake";
    };

    checks-steps-missing = {
      message = args: "the check ${args.rendered.check or "?"} declares no steps";
      help = "give it a steps list, each step carrying a name and a run fragment";
    };

    checks-step-malformed = {
      message = args: "a step of the check ${args.rendered.check or "?"} is not a build step";
      help = "a step is an attrset carrying a name and a run fragment, both strings";
    };

    # the refusal comes from the layer that will build it, so its own sentence
    # is carried rather than restated
    checks-plan-refused = {
      message =
        args: "the check ${args.rendered.check or "?"} was refused, ${args.rendered.reason or "?"}";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.checks-interior { }
    else
      fx.seq (
        lib.concatMap (
          name:
          let
            steps = stepsOf (declaredOf value.${name});
            wellShaped = steps != [ ] && builtins.all isStep steps;
          in
          lib.optional (steps == [ ]) (
            emit.checks-steps-missing {
              at = [ name ];
              context.check = name;
            }
          )
          ++ lib.optional (steps != [ ] && !builtins.all isStep steps) (
            emit.checks-step-malformed {
              at = [ name ];
              context.check = name;
            }
          )
          ++ lib.optionals wellShaped (
            map (
              problem:
              emit.checks-plan-refused {
                at = [ name ];
                context = {
                  check = name;
                  reason = problem.message or "no reason given";
                };
              }
            ) (planFor name steps).errors
          )
        ) (builtins.attrNames value)
      );

  compile = {
    # what leaves the independent half is the description, which is what a
    # kernel checked record is allowed to hold
    independent = value: lib.mapAttrs (_: declared: { steps = stepsOf (declaredOf declared); }) value;

    # the package set arrives in the context, so this is the one place a
    # declared check becomes a derivation
    dependent =
      ctx: compiled:
      lib.mapAttrs (
        name: described:
        fx.build.materialize {
          inherit (ctx) pkgs;
          inherit ((planFor name described.steps)) plan;
        }
      ) compiled;
  };
}
