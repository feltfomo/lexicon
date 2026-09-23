# commands are build plans projected as apps for nix run.
#
# TODO command programs use the declaration name as their binary name. add an
# explicit field only if that convention changes.
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
  name = "commands";

  kinds = [
    "host"
    "fleet"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    commands-interior = {
      message = "a commands block must be an attrset of declared commands";
      help = "write the block as an attrset keyed by the name each command is run under";
    };

    commands-steps-missing = {
      message = args: "the command ${args.rendered.command or "?"} declares no steps";
      help = "give it a steps list, each step carrying a name and a run fragment";
    };

    commands-step-malformed = {
      message = args: "a step of the command ${args.rendered.command or "?"} is not a build step";
      help = "a step is an attrset carrying a name and a run fragment, both strings";
    };

    commands-plan-refused = {
      message =
        args: "the command ${args.rendered.command or "?"} was refused, ${args.rendered.reason or "?"}";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.commands-interior { }
    else
      fx.seq (
        lib.concatMap (
          name:
          let
            steps = stepsOf (declaredOf value.${name});
            wellShaped = steps != [ ] && builtins.all isStep steps;
          in
          lib.optional (steps == [ ]) (
            emit.commands-steps-missing {
              at = [ name ];
              context.command = name;
            }
          )
          ++ lib.optional (steps != [ ] && !builtins.all isStep steps) (
            emit.commands-step-malformed {
              at = [ name ];
              context.command = name;
            }
          )
          ++ lib.optionals wellShaped (
            map (
              problem:
              emit.commands-plan-refused {
                at = [ name ];
                context = {
                  command = name;
                  reason = problem.message or "no reason given";
                };
              }
            ) (planFor name steps).errors
          )
        ) (builtins.attrNames value)
      );

  compile = {
    independent = value: lib.mapAttrs (_: declared: { steps = stepsOf (declaredOf declared); }) value;

    # the package set arrives in the context, so this is where a command
    # becomes a derivation and the app value naming the program inside it
    dependent =
      ctx: compiled:
      lib.mapAttrs (
        name: described:
        let
          built = fx.build.materialize {
            inherit (ctx) pkgs;
            inherit ((planFor name described.steps)) plan;
          };
        in
        {
          type = "app";
          program = "${built}/bin/${name}";
        }
      ) compiled;
  };
}
