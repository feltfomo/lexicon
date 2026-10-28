# praxis callback counts, and which callbacks ran before each exception. a
# shared selection checks and normalizes once, and a failing reference reaches
# its envelope before anything later
let
  failed = sequence: {
    fails = true;
    inherit sequence;
  };
in
{
  prefix = "praxis";
  cells = {
    sharedProbe.counts = {
      check = 3;
      normalize = 1;
    };
    referenceProbe.counts."reference probe" = 1;
    alternatingProbe.counts.predicate = 4;
    factoryProbe.counts.factory = 2;
    "exceptions.reference" = failed [ ];
    "exceptions.normalize" = failed [ ];
    "exceptions.predicate" = failed [ ];
    "exceptions.input" = failed [ ];
    "exceptions.referenceProbe" = failed [ ];
    "exceptions.referenceCode" = failed [ "reference envelope" ];
    "exceptions.referenceSeverity" = failed [
      "reference envelope"
      "code"
    ];
    "exceptions.referenceEnvelope" = failed [ "reference envelope" ];
    "exceptions.referenceFactory" = failed [ ];
    "exceptions.memberOrder" = failed [ "reference envelope" ];
  };
}
