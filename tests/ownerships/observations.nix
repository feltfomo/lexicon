{
  lib,
  axiom,
  ownerships,
}:
let
  tracedAxiom = axiom // {
    phases = axiom.phases // {
      compile = args: builtins.trace "fleet registration" (axiom.phases.compile args);
    };
    schema = axiom.schema // {
      compile =
        args:
        let
          compiled = axiom.schema.compile args;
        in
        if
          args.order or [ ] == [
            "children"
            "value"
            "label"
            "source"
          ]
        then
          value: builtins.trace "fleet schema ${value.label or "unnamed"}" (compiled value)
        else
          compiled;
    };
  };
  api = ownerships { axiom = tracedAxiom; };
  roster = api.toRoster [
    (api.define.host "a")
    (api.define.host "b")
    (api.define.user "user" {
      hosts = [
        "a"
        "b"
      ];
    })
  ];
  doors = api.mkResolvers roster;
  ctx = {
    host.name = "a";
  };
  otherCtx = {
    host.name = "b";
  };
  units = [
    {
      label = "parent";
      when = _: builtins.trace "fleet predicate" true;
      value.values = [ 0 ];
      children = [
        {
          label = "child";
          value.values = [ 1 ];
        }
      ];
    }
  ];
  prepared = doors.systemPrepared units;
  first = prepared ctx;
  stage = name: {
    view = "leaf";
    run = _: leaf: builtins.trace "fleet ${name} ${leaf.label}" [ ];
  };
  base = {
    registry = { };
    stages = [
      (stage "one")
      (stage "two")
      {
        view = "tree";
        run = _: builtins.trace "fleet tree" [ ];
      }
      {
        view = "survivors";
        run = _: builtins.trace "fleet survivors" [ ];
      }
    ];
  };
  stageUnits = [
    {
      label = "a";
      value.a = true;
    }
    {
      label = "b";
      value.b = true;
    }
  ];
  trace =
    (api.resolverFor {
      inherit roster base;
      scope = "system";
      projection = "trace";
    })
      stageUnits
      ctx;
  matrix =
    (api.resolverFor {
      inherit roster base;
      scope = "system";
      projection = "matrix";
    })
      {
        units = stageUnits;
      };
  descriptor = {
    name = "custom";
    roster = null;
    allowedScopes = [ "user" ];
    authorKeys = [
      {
        name = "custom";
        order = 10;
        valid = builtins.isInt;
        shapeError = _: throw "fleet shape exception";
      }
    ];
    parse = unit: builtins.seq unit (throw "fleet premature parse");
    axisFor = _: {
      top = 0;
      narrow = _: own: own;
      ctxKey = null;
      isTop = _: true;
      satisfiable = _: true;
      ambiguous = _: [ ];
      observe = _: { select = _: { selected = true; }; };
    };
    ctxClaim = _: { };
    ctxLabel = _: null;
    leafStages = _: [ ];
    scopeError =
      _: _: _:
      throw "fleet scope exception";
  };
  custom = ownerships {
    descriptors = [ descriptor ];
    relations = [ ];
  };
  profiled =
    scalarPolicy: strategies: listStrategy:
    doors.systemProfiled {
      inherit strategies;
      profiles.test = {
        inherit scalarPolicy listStrategy;
        attrsetTreatment = "deep";
      };
      profileForPath = _: "test";
    };
  exceptions = {
    selector = doors.resolveSystem [
      {
        label = "selector";
        when = _: throw "fleet selector exception";
        value.ok = true;
      }
    ] ctx;
    scalar =
      (profiled (
        _: _: _:
        throw "fleet scalar exception"
      ) { ordered = a: b: a ++ b; } "ordered")
        [
          { value.x = 1; }
          { value.x = 2; }
        ]
        ctx;
    list =
      (profiled (
        _: a: _:
        a.value
      ) { broken = _: _: throw "fleet list exception"; } "broken")
        [
          { value.x = [ 1 ]; }
          { value.x = [ 2 ]; }
        ]
        ctx;
    stage =
      (api.resolverFor {
        inherit roster;
        base = {
          registry = { };
          stages = [
            {
              view = "leaf";
              run = _: _: throw "fleet stage exception";
            }
          ];
        };
      })
        [ { value.ok = true; } ]
        ctx;
    shape = custom.mkResolve { } [
      {
        custom = "bad";
        value.ok = true;
      }
    ] ctx;
    scope = custom.mkResolveSystem { } [
      {
        custom = 1;
        value.ok = true;
      }
    ] ctx;
    import = api.importUnits { dir = ./fixtures/import-units/throwing; };
    static = doors.resolveSystem [
      {
        hosts = [ "unknown" ];
        when = _: throw "fleet premature selector";
        value.ok = true;
      }
    ] ctx;
    scopeFirst = doors.resolveSystem [
      {
        users = [ "user" ];
        when = _: throw "fleet premature selector";
        value.ok = true;
      }
    ] ctx;
    shapeFirst = doors.resolveSystem [
      {
        hosts = "bad";
        value = throw "fleet premature schema";
      }
    ] ctx;
    registration =
      (api.resolverFor {
        inherit roster;
        base = {
          registry = { };
          stages = [
            {
              view = "bad";
              run = _: [ ];
            }
          ];
        };
      })
        [ { value.ok = true; } ]
        ctx;
  };
  cells = {
    inherit exceptions;
    prepared = {
      inherit first;
      repeat = first;
      second = prepared otherCtx;
    };
    ordinary = {
      first = doors.resolveSystem units ctx;
      second = doors.resolveSystem units otherCtx;
    };
    trace = {
      inherit (trace) value stageReports;
      keys = map (entry: entry.key) trace.trace;
    };
    matrix = {
      contexts = builtins.attrNames matrix.byContext;
      coverage = matrix.coverage.units;
    };
    lazy = builtins.typeOf (
      (api.resolverFor {
        inherit roster;
        base = {
          registry = { };
          stages = throw "fleet premature registration";
        };
      })
        [ { value.ok = true; } ]
    );
    poison =
      (doors.resolveSystem [
        {
          value = {
            safe = true;
            opaque = throw "fleet opaque payload";
          };
        }
      ] { host = throw "fleet unused context"; }).safe;
    leftFold =
      (profiled (
        _: a: b:
        builtins.trace "fleet scalar" (a.value * 10 + b.value)
      ) { ordered = a: b: a ++ b; } "ordered")
        [
          { value.x = 1; }
          { value.x = 2; }
          { value.x = 3; }
        ]
        ctx;
    listFold =
      (profiled
        (
          _: a: _:
          a.value
        )
        {
          ordered = a: b: builtins.trace "fleet list" (a ++ b);
        }
        "ordered"
      )
        [
          { value.x = [ 1 ]; }
          { value.x = [ 2 ]; }
          { value.x = [ 3 ]; }
        ]
        ctx;
  };

  threw = expr: msg: {
    inherit expr;
    expectedError.type = "ThrownError";
    expectedError.msg = msg;
  };
  values = [
    0
    1
  ];
in
# callback counts and stage order are checked from the same cells by the events
# flake check, since no value shows how often or in which order a callback ran
cells
// {
  tests = {
    "test prepared translation answers repeated and second contexts" = {
      expr = cells.prepared;
      expected = {
        first.values = values;
        repeat.values = values;
        second.values = values;
      };
    };

    "test ordinary translation answers both contexts" = {
      expr = cells.ordinary;
      expected = {
        first.values = values;
        second.values = values;
      };
    };

    "test the trace keeps every leaf key and stage report" = {
      expr = cells.trace;
      expected = {
        value = {
          a = true;
          b = true;
        };
        keys = [
          "0/0"
          "0/1"
        ];
        stageReports = {
          leaf = [
            {
              view = "leaf";
              diagnostics = [ ];
            }
            {
              view = "leaf";
              diagnostics = [ ];
            }
          ];
          tree = [
            {
              view = "tree";
              diagnostics = [ ];
            }
          ];
          survivors = [
            {
              view = "survivors";
              diagnostics = [ ];
            }
          ];
        };
      };
    };

    "test the matrix covers every leaf in both contexts" = {
      expr = cells.matrix;
      expected = {
        contexts = [
          "standalone/a"
          "standalone/b"
        ];
        coverage = {
          leaf-0 = [
            "standalone/a"
            "standalone/b"
          ];
          leaf-1 = [
            "standalone/a"
            "standalone/b"
          ];
        };
      };
    };

    "test a resolver registers its stages only when applied to a context" = {
      expr = cells.lazy;
      expected = "lambda";
    };

    "test an opaque payload and an unused context stay unforced" = {
      expr = cells.poison;
      expected = true;
    };

    "test a custom scalar policy folds left" = {
      expr = cells.leftFold;
      expected.x = 123;
    };

    "test a custom list strategy folds in order" = {
      expr = cells.listFold;
      expected.x = [
        1
        2
        3
      ];
    };

    "test a selector exception surfaces unchanged" =
      threw exceptions.selector "fleet selector exception";
    "test a scalar policy exception surfaces unchanged" =
      threw exceptions.scalar "fleet scalar exception";
    "test a list strategy exception surfaces unchanged" = threw exceptions.list "fleet list exception";
    "test a stage exception surfaces unchanged" = threw exceptions.stage "fleet stage exception";
    "test a custom shape exception surfaces unchanged" = threw exceptions.shape "fleet shape exception";
    "test a custom scope exception surfaces unchanged" = threw exceptions.scope "fleet scope exception";
    "test an importer exception surfaces unchanged" = threw exceptions.import "fleet import exception";
    "test an unsatisfiable claim fails before its selector runs" =
      threw exceptions.static "claim can never be satisfied";
    "test a scope error fails before its selector runs" =
      threw exceptions.scopeFirst "a system-scope \\(host-only\\) unit sets 'users'";
    "test a shape error fails before the payload is read" =
      threw exceptions.shapeFirst "'hosts' must be a list of names";
    "test an unknown stage view fails at registration" =
      threw exceptions.registration "ownerships: unknown stage view \"bad\"";
  };
}
