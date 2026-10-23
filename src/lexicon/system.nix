{
  lib,
  axiom,
  krisis,
  definitions,
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "lexicon/unit";
  };
  optional = validate: {
    inherit validate;
    onInvalid =
      _: _:
      problem {
        code = "field";
        message = "invalid ownership unit diagnostic field";
      };
  };
  unit = definitions.recursive (
    self:
    definitions.record {
      fields = {
        label = optional builtins.isString;
        source = optional builtins.isString;
        mergeProfile = { };
      };
      children = {
        value = definitions.native {
          owner = "NixOS ownership unit";
          validate = v: builtins.isAttrs v || lib.isFunction v || builtins.isPath v;
        };
        children = definitions.collection {
          contextual = true;
          item = self;
        };
      };
    }
  );
  flatten =
    unit: lib.optional (unit ? value) unit.value ++ builtins.concatMap flatten (unit.children or [ ]);
in
{
  merger =
    {
      direct,
      resolvers,
      ownerships,
      roster,
    }:
    if direct then
      units: _: { imports = builtins.concatMap flatten units; }
    else if resolvers != null then
      resolvers.resolveSystem
    else
      ownerships.mkResolveSystem roster;
  block = {
    name = "nixos";
    scope = "system";
    outputs = [ "nixos" ];
    node = definitions.collection {
      contextual = true;
      item = unit;
    };
    lower = { value, context, ... }: {
      nixos = [
        {
          origin = [ "nixos" ];
          module = context.mergeSystem value;
        }
      ];
    };
  };
}
