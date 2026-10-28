# effect callbacks run once per demanded field, a shared continuation runs once
# for both demands, and a mapper's code is read before its severity fails
let
  failed = sequence: {
    fails = true;
    inherit sequence;
  };
in
{
  prefix = "effects-contract";
  cells = {
    callbackProbe.counts = {
      parse = 1;
      normalize = 1;
    };
    sharedProbe.counts."shared continuation" = 1;
    "callbackExceptions.parse" = failed [ ];
    "callbackExceptions.normalize" = failed [ ];
    "callbackExceptions.formatter" = failed [ ];
    "callbackExceptions.dependent" = failed [ ];
    "callbackExceptions.lower" = failed [ ];
    "callbackExceptions.mapper" = failed [ ];
    "callbackExceptions.mappedCode" = failed [ ];
    "callbackExceptions.mappedSeverity" = failed [ "code" ];
    "callbackExceptions.mappedFactory" = failed [ ];
    "callbackExceptions.mappedEnvelope" = failed [ ];
    "callbackExceptions.mappedOrder" = failed [ ];
  };
}
