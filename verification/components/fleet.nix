{
  project,
  component,
  size,
  bad,
}:
let
  inherit (project.inputs.nixpkgs) lib;
  api = project.lib;
  names = builtins.genList (i: "item${toString i}") size;
  records =
    f:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = f name;
      }) names
    );
  ownerships = api.ownerships { };
  roster = ownerships.toRoster (
    map (name: ownerships.define.host name { system = "fleet"; }) names
    ++ [ (ownerships.define.user "user" { hosts = names; }) ]
  );
  doors = ownerships.mkResolvers roster;
  contexts = map (name: {
    host.id = "fleet/${name}";
    user.name = "user";
  }) names;
  units = map (name: {
    hosts = [ (if bad then "unknown" else name) ];
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
  registry = api.registry {
    root = ./.;
    runtimeRoot = null;
    defaultSystem = "fleet";
    hosts = records (_: if bad then { unknown = true; } else { });
    users = records (_: {
      hosts = names;
    });
  };
  customDescriptor = {
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
    descriptors = [ customDescriptor ];
    relations = [ ];
  };
  customUnits = map (name: {
    rank = if bad then "invalid" else 1;
    value.values.${name} = true;
  }) names;
  workloads = {
    fleet-resolve = map (ctx: (doors.resolve units ctx).values) contexts;
    fleet-prepared = map (ctx: (prepared ctx).values) contexts;
    fleet-custom = custom.mkResolveSystem { } customUnits { custom = 1; };
    fleet-trace = {
      inherit (trace) value;
      leaves = map (entry: {
        inherit (entry) key selected rejectedBy;
        checks = builtins.length entry.checkResults;
      }) trace.trace;
      stages = lib.mapAttrs (_: builtins.length) trace.stageReports;
    };
    fleet-matrix = {
      inherit (matrix) byContext coverage hostDiffs;
      dead = builtins.length matrix.dead;
      never = builtins.length matrix.neverSelectedInModeledContexts;
    };
    registry-queries = map (name: {
      users = map (user: user.name) (registry.usersOn name);
      systems = map (host: host.name) (registry.forSystem "fleet");
      hosts = map (host: host.name) (registry.hostsFor name);
      home = registry.homeFor {
        host = name;
        user = name;
      };
    }) names;
  };
in
workloads.${component}
