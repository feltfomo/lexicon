{
  lib,
  axiom,
  krisis,
  krisisSource,
  praxis ? args: import ../../src/praxis.nix args,
}:
let
  poison = throw "praxis effects payload exception";
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "praxis";
  };
  fields = import ../../src/praxis/fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  typeChecks = fields.typeChecks "type";
  predicateChecks =
    (import ../../src/praxis/type-checks.nix {
      inherit lib axiom krisis;
      inherit (fields) diagnostic name;
      nonEmpty =
        value: if value == "throw" then throw "praxis predicate exception" else fields.nonEmpty value;
    })
      "type";
  inherit (krisis) effects;
  inherit (effects) native;
  opaqueCheck = native.validation.check {
    type = native.validation.types.Any;
    code = "praxis/opaque";
    location = poison;
  };
  T = axiom.types;
  reference =
    let
      shape = T.refine "record containing only param" T.attrs (
        value: builtins.attrNames value == [ "param" ]
      );
      body = T.record { param = T.refine "command-style parameter name" T.string fields.name; };
    in
    body // { validate = value: axiom.validation.andThen body.validate (shape.validate value); };
  arguments = T.listOf (
    T.oneOf "string or parameter reference" [
      T.string
      reference
    ]
  );
  oldAt =
    subject: type: value:
    krisis.validateType {
      inherit type;
      code = "praxis/type";
      label = subject;
    } value;
  old = oldAt "probe";
  equal = left: right: left.diagnostics == right.diagnostics;
  argumentValues = [
    42
    [
      1
      false
      { param = false; }
      { }
    ]
    [
      {
        param = poison;
        extra = poison;
      }
    ]
    [
      { param = "valid"; }
      "literal"
    ]
  ];
  scalarTypes = {
    inherit (T) string;
    inherit (T) int;
    inherit (T) bool;
    path = T.refine "non-empty runtime path string" T.string fields.nonEmpty;
  };
  pkgs = {
    bash = "/bash";
    rustPlatform.buildRustPackage = _: poison;
  };
  compile =
    args:
    praxis (
      {
        inherit
          lib
          axiom
          krisis
          pkgs
          ;
      }
      // args
    );
  observedAxiom = axiom // {
    schema = axiom.schema // {
      compile =
        spec: value:
        let
          command = spec.fields ? steps && spec.fields ? parameters;
          observed = spec // {
            fields =
              spec.fields
              // lib.optionalAttrs command {
                description = spec.fields.description // {
                  normalize = value: builtins.trace "praxis normalize" value;
                };
              };
          };
        in
        (if command then builtins.trace "praxis check" else x: x) (axiom.schema.compile observed value);
    };
  };
  shared = compile {
    axiom = observedAxiom;
    commands.good = {
      command = [ "true" ];
      description = "good";
    };
    commands.unused = poison;
    tasks.once = [
      "good"
      "good"
    ];
  };
  injected = krisis // {
    mkReporter = _: {
      finish =
        result:
        if axiom.validation.isSuccess result then
          result.value
        else
          {
            recovered = true;
            opaque = poison;
          };
    };
  };
  injectedDependencies = import ../../src/dependencies.nix {
    inherit lib axiom krisisSource;
    krisis = injected;
  };
  injectedFields = import ../../src/praxis/fields.nix {
    inherit lib axiom problem;
    inherit (injectedDependencies) krisis;
  };
  checksWith =
    overrides:
    (import ../../src/praxis/type-checks.nix (
      {
        inherit lib axiom krisis;
        inherit (fields) diagnostic nonEmpty name;
      }
      // overrides
    ))
      "type";
  fallbackGuard =
    change:
    checksWith {
      diagnostic =
        subject: code: message:
        if lib.hasInfix "expected string" message then
          throw "praxis premature fallback exception"
        else
          builtins.trace "praxis reference envelope" (change (fields.diagnostic subject code message));
    };
  probeChecks = checksWith {
    name = value: builtins.trace "praxis reference probe" (fields.name value);
  };
  alternatingChecks = checksWith {
    nonEmpty = value: builtins.trace "praxis predicate" (fields.nonEmpty value);
  };
  factoryChecks = checksWith {
    diagnostic =
      subject: code: message:
      builtins.trace "praxis factory" (
        (fields.diagnostic subject code message)
        // {
          primary = {
            label = subject;
            source = "authored";
          };
        }
      );
  };
  originalChecks = checksWith {
    krisis = krisis // {
      effects = effects // {
        native = native // {
          validation = native.validation // {
            check = _: _: effects.accept { replacement = poison; };
          };
        };
      };
    };
  };
  tests = {
    "test retained success values match characterization" = {
      expr = builtins.all (
        kind:
        let
          values = {
            string = "value";
            int = 7;
            bool = false;
            path = "/runtime";
          };
          value = values.${kind};
        in
        (typeChecks.scalar "probe" kind value).value == value
        &&
          (typeChecks.choices "probe" kind [
            value
            value
          ]).value == [
            value
            value
          ]
        && (typeChecks.default "probe" kind null).value == null
        && (typeChecks.default "probe" kind value).value == value
      ) (builtins.attrNames scalarTypes);
      expected = true;
    };
    "test failure values are absent" = {
      expr = builtins.all (result: !(result ? value)) [
        (typeChecks.scalar "probe" "int" false)
        (typeChecks.choices "probe" "int" [ false ])
        (typeChecks.default "probe" "int" false)
        (typeChecks.arguments "probe" [ 42 ])
      ];
      expected = true;
    };
    "test retained argument values keep original opaque children" = {
      expr =
        let
          value =
            builtins.head
              (originalChecks.arguments "probe" [
                {
                  safe = true;
                  child = poison;
                }
              ]).value;
        in
        value.safe
        &&
          builtins.attrNames value == [
            "child"
            "safe"
          ];
      expected = true;
    };
    "test argument summaries match characterization" = {
      expr = builtins.all (
        value:
        krisis.summarizeDiagnostics (typeChecks.arguments "probe" value).diagnostics
        == krisis.summarizeDiagnostics (old arguments value).diagnostics
      ) argumentValues;
      expected = true;
    };
    "test outer list rejection suppresses member work" = {
      expr = (typeChecks.arguments "probe" { member = poison; }).diagnostics;
      expected = (old arguments { member = poison; }).diagnostics;
    };
    "test argument authored member and check order" = {
      expr =
        map (d: d.context.validation.path)
          (typeChecks.arguments "probe" [
            1
            false
          ]).diagnostics;
      expected = [
        [ 0 ]
        [ 0 ]
        [ 1 ]
        [ 1 ]
      ];
    };
    "test environment path and content match characterization" = {
      expr =
        (typeChecks.environment "probe" {
          key = false;
          unused = poison;
        } "key").diagnostics;
      expected =
        (krisis.validateType {
          type = T.string;
          code = "praxis/type";
          label = "probe";
          path = [
            "env"
            "key"
          ];
        } false).diagnostics;
    };

    "test configured checker subject and state" = {
      expr =
        builtins.all
          (
            item:
            equal (typeChecks.scalar item.subject "path" item.value) (
              oldAt item.subject scalarTypes.path item.value
            )
          )
          [
            {
              subject = "first";
              value = "";
            }
            {
              subject = "second";
              value = "valid";
            }
            {
              subject = "third";
              value = "";
            }
            {
              subject = "fourth";
              value = "next";
            }
          ];
      expected = true;
    };
    "test configured checker success values" = {
      expr = builtins.all (value: (typeChecks.scalar "probe" "int" value).value == value) [
        1
        2
        3
      ];
      expected = true;
    };
    "test unused configured code" = {
      expr = builtins.isFunction (fields.typeChecks poison).arguments;
      expected = true;
    };
    "test unused native configuration" = {
      expr = builtins.isFunction (
        native.validation.check {
          type = poison;
          code = poison;
          location = poison;
        }
      );
      expected = true;
    };
    "test configured opaque transport" = {
      expr =
        builtins.all
          (
            safe:
            (effects.resultOf (opaqueCheck {
              inherit safe;
              payload = poison;
            })).value.safe == safe
          )
          [
            "first"
            "second"
          ];
      expected = true;
    };
    "test configured predicate per value" = {
      expr =
        (predicateChecks.scalar "first" "path" "valid").diagnostics == [ ]
        && (predicateChecks.scalar "second" "path" "").diagnostics != [ ]
        && (predicateChecks.scalar "third" "path" "next").diagnostics == [ ];
      expected = true;
    };
    "test configured predicate exception" = {
      expr =
        !(builtins.tryEval (
          builtins.deepSeq (builtins.seq (predicateChecks.scalar "first" "path" "valid").diagnostics
            (predicateChecks.scalar "second" "path" "throw").diagnostics
          ) true
        )).success;
      expected = true;
    };
    "test native argument diagnostics" = {
      expr =
        builtins.all
          (
            subject:
            builtins.all (
              value: equal (typeChecks.arguments subject value) (oldAt subject arguments value)
            ) argumentValues
          )
          [
            "probe"
            "other"
          ];
      expected = true;
    };
    "test native scalar list maybe diagnostics" = {
      expr = builtins.all (
        kind:
        builtins.all
          (
            value:
            equal (typeChecks.scalar "probe" kind value) (old scalarTypes.${kind} value)
            && equal (typeChecks.choices "probe" kind value) (old (T.listOf scalarTypes.${kind}) value)
            && equal (typeChecks.default "probe" kind value) (old (T.nullOr scalarTypes.${kind}) value)
          )
          [
            null
            42
            true
            ""
            "valid"
            [
              1
              "bad"
              false
            ]
          ]
      ) (builtins.attrNames scalarTypes);
      expected = true;
    };
    "test malformed reference suppresses payload" = {
      expr =
        (typeChecks.arguments "probe" [
          {
            param = poison;
            extra = poison;
          }
        ]).diagnostics != [ ];
      expected = true;
    };
    "test original reference exception" = {
      expr =
        !(builtins.tryEval (
          builtins.deepSeq (typeChecks.arguments "probe" [ { param = poison; } ]).diagnostics true
        )).success;
      expected = true;
    };
    "test public check terminal recovery" = {
      expr =
        (compile {
          inherit (injectedDependencies) krisis;
          checks = [ "missing" ];
        }).checks.missing.recovered;
      expected = true;
    };
    "test terminal recovery" = {
      expr =
        (injectedFields.finishChecked (fields.reject [ (fields.diagnostic "probe" "type" "bad") ]))
        .recovered;
      expected = true;
    };
  };
in
{
  inherit tests;
  sharedProbe = {
    selected = builtins.attrNames shared.manifests.once.commands;
    description = shared.manifests.once.commands.good.description;
    summary = shared.diagnosticSummaries.good.total;
    repeated = shared.manifests.good.commands.good.description;
  };
  alternatingProbe =
    lib.imap0
      (
        index: value:
        let
          result = alternatingChecks.scalar "subject${toString index}" "path" value;
        in
        {
          count = builtins.length result.diagnostics;
          value = if result.diagnostics == [ ] then result.value else null;
        }
      )
      [
        "valid"
        ""
        "valid"
        ""
      ];
  factoryProbe =
    map (d: { inherit (d) code primary; })
      (factoryChecks.arguments "probe" [ 42 ]).diagnostics;
  referenceProbe = {
    value = (builtins.head (probeChecks.arguments "probe" [ { param = "valid"; } ]).value).param;
    string = builtins.head (probeChecks.arguments "probe" [ "literal" ]).value;
  };
  exceptions = {
    input = (typeChecks.scalar "probe" "int" (throw "praxis input exception")).diagnostics;
    referenceProbe =
      (
        (checksWith {
          name = _: throw "praxis reference probe exception";
          diagnostic =
            _: _: _:
            throw "praxis premature fallback exception";
        }).arguments
        "probe"
        [ { param = "valid"; } ]
      ).diagnostics;
    referenceCode =
      (
        (fallbackGuard (
          d:
          d
          // {
            code = throw "praxis reference code exception";
            severity = throw "praxis premature severity exception";
          }
        )).arguments
        "probe"
        [ 42 ]
      ).diagnostics;
    referenceSeverity =
      (
        (fallbackGuard (
          d:
          d
          // {
            code = builtins.trace "praxis code" d.code;
            severity = throw "praxis reference severity exception";
          }
        )).arguments
        "probe"
        [ 42 ]
      ).diagnostics;
    referenceEnvelope = ((fallbackGuard (d: d // { code = ""; })).arguments "probe" [ 42 ]).diagnostics;
    referenceFactory =
      (
        (checksWith {
          diagnostic =
            _: _: _:
            throw "praxis factory exception";
        }).arguments
        "probe"
        [ 42 ]
      ).diagnostics;
    memberOrder =
      ((fallbackGuard (d: d // { code = throw "praxis first member exception"; })).arguments "probe" [
        42
        poison
      ]).diagnostics;

    predicate =
      builtins.seq (predicateChecks.scalar "first" "path" "valid").diagnostics
        (predicateChecks.scalar "second" "path" "throw").diagnostics;
    reference =
      (compile {
        commands.bad = {
          command = [ "true" ];
          args = [ { param = poison; } ];
        };
      }).diagnostics.bad;
    normalize =
      (compile {
        axiom = axiom // {
          schema = axiom.schema // {
            compile =
              spec:
              axiom.schema.compile (
                spec
                // {
                  fields =
                    spec.fields
                    // lib.optionalAttrs (spec.fields ? steps && spec.fields ? parameters) {
                      description = spec.fields.description // {
                        normalize = _: throw "praxis normalize exception";
                      };
                    };
                }
              );
          };
        };
        commands.bad = {
          command = [ "true" ];
          description = "bad";
        };
      }).manifests.bad.commands.bad.description;
  };
}
