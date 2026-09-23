# a package is declared the same way a check is, by its build steps, and for
# the same reason. the description crosses into the kernel and the derivation
# is made in the dependent half
#
# it is a separate block rather than a mode of the check block because the
# attribute it projects into is a different one, and a single block keyed by
# output name would make its validator a switch over names
{ lib, fx, ... }:
let
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
  name = "packages";

  kinds = [
    "host"
    "fleet"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    packages-interior = {
      message = "a packages block must be an attrset of declared packages";
      help = "write the block as an attrset keyed by the name each package takes in the flake";
    };

    packages-steps-missing = {
      message = args: "the package ${args.rendered.package or "?"} declares no steps";
      help = "give it a steps list, each step carrying a name and a run fragment";
    };

    packages-step-malformed = {
      message = args: "a step of the package ${args.rendered.package or "?"} is not a build step";
      help = "a step is an attrset carrying a name and a run fragment, both strings";
    };

    packages-plan-refused = {
      message =
        args: "the package ${args.rendered.package or "?"} was refused, ${args.rendered.reason or "?"}";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.packages-interior { }
    else
      fx.seq (
        lib.concatMap (
          name:
          let
            steps = stepsOf (declaredOf value.${name});
            wellShaped = steps != [ ] && builtins.all isStep steps;
          in
          lib.optional (steps == [ ]) (
            emit.packages-steps-missing {
              at = [ name ];
              context.package = name;
            }
          )
          ++ lib.optional (steps != [ ] && !builtins.all isStep steps) (
            emit.packages-step-malformed {
              at = [ name ];
              context.package = name;
            }
          )
          ++ lib.optionals wellShaped (
            map (
              problem:
              emit.packages-plan-refused {
                at = [ name ];
                context = {
                  package = name;
                  reason = problem.message or "no reason given";
                };
              }
            ) (planFor name steps).errors
          )
        ) (builtins.attrNames value)
      );

  compile = {
    independent = value: lib.mapAttrs (_: declared: { steps = stepsOf (declaredOf declared); }) value;

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
