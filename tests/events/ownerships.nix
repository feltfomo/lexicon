# callback counts of the ownerships fixture. prepared translation runs its
# schema once across contexts and ordinary translation once per context, stage
# registration happens once per resolver, and leaf stages run stage by stage in
# a trace but context by context in a matrix
let
  stages = survivors: {
    registration = 1;
    "one a" = 1;
    "one b" = 1;
    "two a" = 1;
    "two b" = 1;
    tree = 1;
    inherit survivors;
  };
  leafOrder = events: {
    prefixes = [
      "one "
      "two "
    ];
    inherit events;
  };
in
{
  prefix = "fleet";
  cells = {
    prepared.counts = {
      registration = 1;
      "schema parent" = 1;
      "schema child" = 1;
      predicate = 4;
    };
    ordinary.counts = {
      registration = 1;
      "schema parent" = 2;
      "schema child" = 2;
      predicate = 4;
    };
    trace = {
      counts = stages 1;
      ordered = leafOrder [
        "one a"
        "one b"
        "two a"
        "two b"
      ];
    };
    matrix = {
      counts = stages 2;
      ordered = leafOrder [
        "one a"
        "two a"
        "one b"
        "two b"
      ];
    };
    leftFold.counts = {
      registration = 1;
      scalar = 2;
    };
    listFold.counts = {
      registration = 1;
      list = 2;
    };
    "exceptions.selector" = {
      fails = true;
      context = [ "while evaluating 'when' predicate" ];
    };
    "exceptions.import" = {
      fails = true;
      context = [ "while importing ownership units" ];
    };
  };
}
