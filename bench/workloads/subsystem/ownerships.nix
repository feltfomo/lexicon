# ownership resolution over one host, then over a fleet of size hosts through
# ordinary, prepared, custom-axis, traced and matrix selection. every unit has an
# inactive throwing payload, so a case that forces it fails on both sides
{
  api,
  lib,
  names,
  ...
}:
let
  ownerships = api.ownerships { };

  single = ownerships.toRoster [
    (ownerships.define.host "host" { system = "x86_64-linux"; })
    (ownerships.define.user "user" { hosts = [ "host" ]; })
  ];

  fleet = ownerships.toRoster (
    map (name: ownerships.define.host name { system = "fleet"; }) names
    ++ [ (ownerships.define.user "user" { hosts = names; }) ]
  );
  doors = ownerships.mkResolvers fleet;

  contexts = map (name: {
    host.id = "fleet/${name}";
    user.name = "user";
  }) names;

  units = map (name: {
    hosts = [ name ];
    children = [
      { values.${name} = true; }
      {
        when = _: false;
        value.opaque = throw "inactive fleet payload";
      }
    ];
  }) names;

  prepared = doors.prepared units;
  trace = doors.trace units (builtins.head contexts);
  matrix = doors.matrix { inherit units; };

  # a descriptor outside the built-in vocabulary, so custom axes stay measured
  rank = {
    name = "custom";
    roster = null;
    allowedScopes = [ "system" ];
    authorKeys = [
      {
        name = "rank";
        order = 10;
        valid = builtins.isInt;
        shapeError = _: "rank must be an integer";
      }
    ];
    parse = unit: lib.optionalAttrs (unit ? rank) { custom = unit.rank; };
    axisFor = _: {
      top = 0;
      ctxKey = "custom";
      isTop = n: n == 0;
      narrow = a: b: if a > b then a else b;
      satisfiable = n: n >= 0;
      ambiguous = _: [ ];
      observe = n: {
        select = ctx: { selected = ctx.custom >= n; };
      };
      select = n: ctx: ctx.custom >= n;
    };
    ctxClaim = _: { };
    ctxLabel = _: null;
    leafStages = _: [ ];
    scopeError =
      _: _: _:
      "rank unavailable";
  };
  custom = api.ownerships {
    descriptors = [ rank ];
    relations = [ ];
  };
in
{
  resolve =
    ownerships.mkResolve single
      (map (name: {
        users = [ "user" ];
        values.${name} = true;
      }) names)
      {
        host.name = "host";
        host.system = "x86_64-linux";
        user.name = "user";
      };

  fleet-resolve = map (ctx: (doors.resolve units ctx).values) contexts;

  fleet-prepared = map (ctx: (prepared ctx).values) contexts;

  fleet-custom = custom.mkResolveSystem { } (map (name: {
    rank = 1;
    value.values.${name} = true;
  }) names) { custom = 1; };

  fleet-trace = {
    inherit (trace) value;
    leaves = map (entry: {
      inherit (entry) key selected rejectedBy;
      checks = builtins.length entry.checkResults;
    }) trace.trace;
    stages = lib.mapAttrs (_: builtins.length) trace.stageReports;
  };

  # the matrix never demands a configuration payload, only selections and counts
  fleet-matrix = {
    inherit (matrix) byContext coverage hostDiffs;
    dead = builtins.length matrix.dead;
    never = builtins.length matrix.neverSelectedInModeledContexts;
  };
}
