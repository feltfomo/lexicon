{
  lib,
  axiom,
  krisis,
  lexicon,
}:
let
  inherit (krisis.effects) fx native fromAxiom;
  inherit (fx.state) mkThunk forceThunk;
  inherit (axiom) validation;
  poison = throw "effects contract poison";
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  run = native.report.run { };
  checked = computation: forceThunk (run computation).outcome.value;
  diagnostic = code: severity: {
    inherit code severity;
    message = "message ${code}";
  };
  first = diagnostic "first" "error";
  second = diagnostic "second" "warning";
  invalid = {
    diagnostics = [
      first
      second
    ];
    value = poison;
  };
  emitted = krisis.effects.run invalid;
  independent = native.validation.all [
    (fromAxiom (validation.failure [ first ]))
    (fromAxiom (validation.failure [ second ]))
  ];
  skipped = native.validation.andThen (_: poison) (fromAxiom (validation.failure [ second ]));
  opaque = {
    safe = true;
    payload = poison;
  };
  transported = krisis.effects.run (validation.success opaque);
  deferred = krisis.effects.run {
    diagnostics = [
      {
        code = "opaque";
        severity = "warning";
        message = poison;
        context = poison;
      }
    ];
    value = poison;
  };
  emit =
    code:
    native.report.emit {
      inherit code;
      severity = "warning";
      message = poison;
      context = poison;
    };
  scoped =
    native.report.run
      {
        handlers.outer = { state, ... }: {
          inherit state;
          resume = null;
        };
      }
      (
        native.report.withContext
          {
            namespace = "root";
            primary = poison;
          }
          (
            fx.bind (emit "first") (
              _:
              fx.bind
                (native.report.withContext {
                  namespace = "nested";
                  primary = poison;
                } (fx.bind (fx.send "outer" null) (_: emit "second")))
                (
                  _:
                  fx.bind (emit "third") (
                    _:
                    native.report.withContext {
                      namespace = "sibling";
                      primary = poison;
                    } (emit "fourth")
                  )
                )
            )
          )
      );
  rawState = fx.handle {
    state = null;
    handlers.write = { param, ... }: {
      state = param;
      resume = null;
    };
  } (fx.bind (fx.send "write" opaque) (_: fx.pure 1));
  protectedState = fx.handle {
    state = null;
    handlers.write = { param, ... }: {
      state = mkThunk param;
      resume = null;
    };
  } (fx.bind (fx.send "write" opaque) (_: fx.pure (mkThunk opaque)));
  problem = krisis.mkDiagnosticFactory { codePrefix = "contract"; };
  schema =
    fields:
    axiom.schema.compile {
      inherit fields;
      onRecord =
        _:
        problem {
          code = "record";
          message = "expected record";
        };
      onUnknown =
        name: _:
        problem {
          code = "unknown";
          message = name;
        };
    };
  normalized =
    (schema {
      optional = { };
      nullable.validate = value: value == null;
      defaulted = {
        default = "authored";
        parse = value: validation.success "parsed ${value}";
      };
    })
      { nullable = null; };
  ordered =
    (axiom.schema.compile {
      order = [
        "b"
        "a"
      ];
      fields = lib.genAttrs [ "a" "b" ] (name: {
        parse =
          _:
          validation.failure [
            (problem {
              code = name;
              message = name;
            })
          ];
      });
      onRecord = _: poison;
      onUnknown =
        name: _:
        problem {
          code = "unknown";
          message = name;
        };
    })
      {
        a = null;
        b = null;
        z = poison;
      };
  reporter = krisis.mkReporter {
    formatHeader = count: "errors ${toString count}";
    formatDiagnostic = item: "custom ${item.code}";
    separator = " | ";
  };
  pkgs = lexicon.inputs.nixpkgs.legacyPackages.x86_64-linux;
  target = {
    host = {
      name = "host";
      system = "x86_64-linux";
      id = "x86_64-linux/host";
    };
    user = {
      name = "user";
      home = "/srv/user";
    };
  };
  args = target // {
    inherit lib pkgs;
    config = {
      networking.hostName = "host";
      lexicon.furnish.declarations = [ { } ];
    };
  };
  bookmarks = lexicon.lib.lexicon.configure {
    extensions = [ (import ./declarations/fixtures/bookmarks.nix) ];
  };
  bookmarkDeclaration = bookmarks.forTarget { inherit target; } {
    bookmarks.entries = [
      {
        source = "/external/book";
        destination = ".bookmarks/book";
      }
    ];
  };
  bookmarkEntries =
    (builtins.head (
      builtins.filter (
        module: builtins.isAttrs module && module ? lexicon
      ) (bookmarkDeclaration.nixos args).imports
    )).lexicon.furnish.declarations;
  injected = {
    renderPlain = item: "injected ${item.code}";
    summarizeDiagnostics = items: (krisis.summarizeDiagnostics items) // { injected = true; };
    mkDiagnosticFactory =
      defaults: raw: (krisis.mkDiagnosticFactory defaults raw) // { message = "injected diagnostic"; };
  };
  hookExtension = { krisis, definitions, ... }: {
    name = "hook";
    blocks = [
      {
        name = "hook";
        scope = "user";
        outputs = [ "homeManager" ];
        node = definitions.record { };
        lower = _: {
          homeManager = [
            {
              origin = [ "hook" ];
              module =
                let
                  item = (krisis.mkDiagnosticFactory { codePrefix = "extension"; }) {
                    code = "made";
                    message = "original";
                  };
                in
                {
                  hook = {
                    rendered = krisis.renderPlain item;
                    inherit (item) message;
                    injected = (krisis.summarizeDiagnostics [ item ]).injected or false;
                    identity = krisis.safeIdentity {
                      value = poison;
                      label = "authored";
                    };
                  };
                };
            }
          ];
        };
      }
    ];
  };
  hooked = (lexicon.lib.lexicon.configure { extensions = [ hookExtension ]; }).forTarget {
    inherit target;
    krisis = injected;
  } { hook = { }; };
  inherit ((builtins.head (hooked.homeManager args).imports)) hook;
  injectedReporter = {
    mkReporter = options: (krisis.mkReporter options) // { finish = _: "injected finish"; };
  };
  publicReport = lexicon.lib.report { krisis = injectedReporter; };
  projectedReporter = {
    mkReporter =
      options:
      let
        original = krisis.mkReporter options;
      in
      original
      // {
        finish =
          result:
          if result.diagnostics == [ ] && builtins.isBool result.value then
            "ignored structural terminal value"
          else
            original.finish result;
      };
  };
  projectedDeclaration = lexicon.lib.lexicon.forTarget {
    inherit target;
    krisis = projectedReporter;
  } { homeManager.safe = true; };
  identityAxiom = axiom // {
    identity = axiom.identity // {
      render = _: "injected identity";
    };
  };
  identityDeclaration =
    (lexicon.lib.lexicon.configure { extensions = [ hookExtension ]; }).forTarget
      {
        inherit target;
        axiom = identityAxiom;
      }
      { hook = { }; };
  controlExceptions = {
    inspection = krisis.safeShapeWith { maxAttrs = -1; } poison;
    summary = krisis.summarizeDiagnostics null;
    identity = krisis.safeIdentity {
      value = poison;
      noun = 1;
    };
  };
  praxis = lexicon.lib.praxis {
    inherit pkgs;
    krisis = injected;
    commands = {
      selected = [ "true" ];
      sibling = poison;
    };
  };
  callbackProbe =
    let
      parsed =
        (schema {
          parsed.parse = value: builtins.trace "effects-contract parse" (validation.success value);
          normalized.normalize = value: builtins.trace "effects-contract normalize" value;
        })
          {
            parsed = "parse";
            normalized = "normalize";
          };
      value = krisis.effects.finish (_: poison) parsed;
    in
    {
      first = value;
      second = value;
    };
  sharedProbe =
    let
      computation = krisis.effects.share (
        native.validation.andThen
          (value: builtins.trace "effects-contract shared continuation" (krisis.effects.accept value))
          (
            krisis.effects.accept {
              safe = true;
              opaque = poison;
            }
          )
      );
    in
    {
      first = (krisis.effects.finishComputation (_: poison) computation).safe;
      second = (krisis.effects.finishComputation (_: poison) computation).safe;
    };
  mapped = krisis.effects.mappedResultFromReport;
  warningReport = run (
    fx.bind (native.report.emit {
      code = "native";
      severity = "warning";
      message = poison;
      context = poison;
    }) (_: krisis.effects.accept opaque)
  );
  retained = {
    code = "mapped";
    severity = "warning";
    message = poison;
    primary = poison;
    secondaryLabels = poison;
    notes = poison;
    help = poison;
    context = poison;
  };
  mappedProbe = mapped (_: retained) warningReport;
  malformedReports = [
    {
      diagnostics = [ ];
      outcome._con = "Failure";
    }
    {
      diagnostics = [ ];
      outcome = {
        _con = "Success";
        value = mkThunk { _con = "Invalid"; };
      };
    }
    {
      diagnostics = [ first ];
      outcome._con = "Unknown";
    }
    {
      diagnostics = [ first ];
      outcome = {
        _con = "Failure";
        value = poison;
      };
    }
    {
      diagnostics = [ first ];
      outcome = {
        _con = "Success";
        value = mkThunk { _con = "Unknown"; };
      };
    }
    {
      diagnostics = [ first ];
      outcome = {
        _con = "Success";
        value = mkThunk {
          _con = "Invalid";
          value = poison;
        };
      };
    }
    {
      diagnostics = [ ];
      outcome = {
        _con = "Success";
        value = mkThunk { _con = "Valid"; };
      };
    }
    {
      diagnostics = [ ];
      outcome = {
        _con = "Success";
        value = opaque;
      };
    }
  ];
  projectionProbe = {
    inherit ((builtins.head mappedProbe.diagnostics)) code;
    noValue = !(mappedProbe ? value);
    summary = krisis.summarizeDiagnostics mappedProbe.diagnostics;
    recovered =
      (krisis.effects.finishReport (items: {
        safe = (builtins.head items).code == "mapped";
        payload = poison;
      }) (krisis.effects.run mappedProbe)).safe;
  };
  callbackExceptions = {
    mapper = (mapped (_: throw "effects contract mapper exception") warningReport).diagnostics;
    mappedCode =
      (mapped (
        _:
        retained
        // {
          code = throw "effects contract code exception";
          severity = throw "effects contract premature severity";
        }
      ) warningReport).diagnostics;
    mappedSeverity =
      (mapped (
        _:
        retained
        // {
          code = builtins.trace "effects-contract code" "mapped";
          severity = throw "effects contract severity exception";
        }
      ) warningReport).diagnostics;
    mappedFactory =
      (mapped (
        _: (krisis.mkDiagnosticFactory { }) (throw "effects contract factory exception")
      ) warningReport).diagnostics;
    mappedEnvelope = (mapped (_: retained // { code = ""; }) warningReport).diagnostics;
    mappedOrder =
      (mapped (
        d:
        if d.code == "first" then
          throw "effects contract first envelope exception"
        else
          throw "effects contract premature second envelope"
      ) (run independent)).diagnostics;
    parse = (schema { value.parse = _: throw "effects contract parse exception"; }) { value = 1; };
    normalize = (schema { value.normalize = _: throw "effects contract normalize exception"; }) {
      value = 1;
    };
    formatter =
      (krisis.mkReporter {
        formatDiagnostic = _: throw "effects contract formatter exception";
      }).render
        [ first ];
    dependent = run (
      native.validation.andThen (_: throw "effects contract dependent exception") (
        fromAxiom (validation.success 1)
      )
    );
    lower =
      let
        extension =
          args:
          let
            original = hookExtension args;
          in
          original
          // {
            blocks = map (
              block:
              block
              // {
                lower = _: throw "effects contract lower exception";
              }
            ) original.blocks;
          };
        declaration = (lexicon.lib.lexicon.configure { extensions = [ extension ]; }).forTarget {
          inherit target;
        } { hook = { }; };
      in
      (declaration.homeManager args).imports;
  };
  tests = {
    "test mapped failure has no success value" = {
      expr = !(mappedProbe ? value) && projectionProbe.recovered;
      expected = true;
    };
    "test mapped presentation and context stay deferred" = {
      expr = projectionProbe.code == "mapped" && projectionProbe.summary.total == 1;
      expected = true;
    };
    "test mapped success recovers qualified carriers" = {
      expr = (mapped (_: poison) transported).value.safe;
      expected = true;
    };
    "test report eliminators reject missing evidence and impossible constructors" = {
      expr = builtins.all (
        report:
        rejects (builtins.seq (krisis.effects.resultFromReport report) true)
        && rejects (builtins.seq (mapped (_: first) report) true)
        && rejects (krisis.effects.finishReport (_: true) report)
      ) malformedReports;
      expected = true;
    };
    "test shared elimination rejects invalid without evidence" = {
      expr = krisis.effects.finishComputation (_: true) (
        krisis.effects.share (fx.pure { _con = "Invalid"; })
      );
      expectedError.type = "ThrownError";
      expectedError.msg = "lexicon: invalid validation without diagnostics";
    };
    "test mapped diagnostic order and authored content" = {
      expr =
        let
          result = mapped (d: {
            inherit (d) code;
            inherit (d) severity;
            message = "authored ${d.code}";
            primary = {
              label = "origin";
              source = "source";
            };
            context.path = [
              "authored"
              2
            ];
          }) (run independent);
        in
        result.diagnostics == map
          (d: {
            inherit (d) code severity;
            message = "authored ${d.code}";
            primary = {
              label = "origin";
              source = "source";
            };
            context.path = [
              "authored"
              2
            ];
          })
          [
            first
            second
          ]
        && !(result ? value);
      expected = true;
    };

    "test structural terminal projection does not replace prepared entry" = {
      expr = (builtins.head (projectedDeclaration.homeManager args).imports).safe;
      expected = true;
    };
    "test shared validation retains diagnostics and suppresses dependent work" = {
      expr =
        let
          computation = krisis.effects.share (
            native.validation.all [
              (krisis.effects.fromDiagnostics [ first ] poison)
              (krisis.effects.fromDiagnostics [ second ] poison)
            ]
          );
        in
        krisis.effects.finishComputation (items: map (item: item.code) items) (
          native.validation.andThen (_: poison) computation
        ) == [
          first.code
          second.code
        ];
      expected = true;
    };
    "test shared validation transports opaque successes" = {
      expr =
        let
          computation = krisis.effects.share (krisis.effects.accept opaque);
        in
        (krisis.effects.finishComputation (_: poison) computation).safe
        && (krisis.effects.finishComputation (_: poison) computation).safe;
      expected = true;
    };
    "test string and record diagnostics recover in order" = {
      expr =
        krisis.effects.finishComputation
          (items: [
            (builtins.head items)
            (builtins.elemAt items 1).code
          ])
          (
            native.validation.all [
              (krisis.effects.fromDiagnostics [ "authored string" ] poison)
              (krisis.effects.fromDiagnostics [ first ] poison)
            ]
          );
      expected = [
        "authored string"
        first.code
      ];
    };
    "test composed checked values protect arbitrary payloads" = {
      expr =
        (krisis.effects.finishComputation (_: poison) (
          native.validation.andThen
            (
              values:
              krisis.effects.accept {
                context = builtins.elemAt values 0;
                payload = builtins.elemAt values 1;
                predecessor = builtins.elemAt values 2;
              }
            )
            (
              native.validation.all [
                (krisis.effects.accept {
                  safe = true;
                  opaque = poison;
                })
                (krisis.effects.accept { opaque = poison; })
                (krisis.effects.accept { previous = poison; })
              ]
            )
        )).context.safe;
      expected = true;
    };
    "test old location poison stays opaque" = {
      expr =
        (krisis.effects.run {
          diagnostics = [
            {
              code = "opaque";
              severity = "warning";
              message = poison;
              primary = poison;
            }
          ];
        }).summary.total;
      expected = 1;
    };
    "test empty old primary is absent in native presentation" = {
      expr =
        (native.render.project (
          builtins.head
            (krisis.effects.run {
              diagnostics = [
                (krisis.mkDiagnostic {
                  code = "empty";
                  severity = "warning";
                  message = "empty";
                  primary = { };
                })
              ];
            }).diagnostics
        )).primary;
      expected = null;
    };
    "test malformed inspection options fail before payload" = {
      expr = controlExceptions.inspection;
      expectedError.type = "ThrownError";
      expectedError.msg = "krisis: render option 'maxAttrs' must be a non-negative integer; got int";
    };
    "test malformed summary input fails" = {
      expr = controlExceptions.summary;
      expectedError.type = "ThrownError";
      expectedError.msg = "krisis: diagnostic summary requires a list";
    };
    "test injected axiom identity participates" = {
      expr = (builtins.head (identityDeclaration.homeManager args).imports).hook.identity;
      expected = "injected identity";
    };
    "test shared handler runs remain isolated" = {
      expr =
        emitted.summary.total == 2
        && (krisis.effects.run (validation.success true)).summary.total == 0
        && (krisis.effects.run (validation.success true)).outcome._con == "Success";
      expected = true;
    };
    "test malformed success result is rejected" = {
      expr = rejects (krisis.effects.run { diagnostics = [ ]; }).outcome;
      expected = true;
    };
    "test malformed diagnostics result is rejected" = {
      expr = rejects (krisis.effects.run { diagnostics = { }; }).outcome;
      expected = true;
    };
    "test independent diagnostics stay ordered" = {
      expr = map (item: item.code) (run independent).diagnostics;
      expected = [
        "first"
        "second"
      ];
    };
    "test dependent callback is suppressed" = {
      expr = (checked skipped)._con;
      expected = "Invalid";
    };
    "test invalid has no value" = {
      expr = builtins.attrNames (checked skipped);
      expected = [ "_con" ];
    };
    "test failure has no value" = {
      expr = builtins.attrNames emitted.outcome;
      expected = [ "_con" ];
    };
    "test failure constructor is explicit" = {
      expr = emitted.outcome._con;
      expected = "Failure";
    };
    "test valid and success eliminate through carriers" = {
      expr =
        transported.outcome._con == "Success"
        && (forceThunk transported.outcome.value)._con == "Valid"
        && (forceThunk (forceThunk transported.outcome.value).value).safe;
      expected = true;
    };
    "test returned poison stays opaque" = {
      expr = builtins.attrNames (forceThunk (forceThunk transported.outcome.value).value);
      expected = [
        "payload"
        "safe"
      ];
    };
    "test poisoned input state and summary stay opaque" = {
      expr = deferred.summary.total == 1 && deferred.summary.byCode.opaque == 1;
      expected = true;
    };
    "test old diagnostic recovery stays opaque" = {
      expr = krisis.effects.finish (items: builtins.attrNames (builtins.head items)) {
        diagnostics = [
          {
            code = "opaque";
            severity = "error";
            message = poison;
            context = poison;
          }
        ];
      };
      expected = [
        "code"
        "context"
        "message"
        "severity"
      ];
    };
    "test nested and sibling scopes restore" = {
      expr = map (item: item.code) scoped.diagnostics;
      expected = [
        "root/first"
        "nested/second"
        "root/third"
        "sibling/fourth"
      ];
    };
    "test scoped poison stays opaque" = {
      expr = scoped.summary.total;
      expected = 4;
    };
    "test handler collisions fail" = {
      expr = native.report.run {
        handlers."krisis.emit" = poison;
      } (fx.pure 1);
      expectedError.type = "ThrownError";
      expectedError.msg = "krisis: handler collision krisis\\.emit";
    };
    "test unhandled effects fail" = {
      expr = run (fx.send "effects-contract.unhandled" null);
      expectedError.type = "ThrownError";
      expectedError.msg = "nix-effects: unhandled effect 'effects-contract\\.unhandled'";
    };
    "test raw state control forces poison" = {
      expr = rawState.value;
      expectedError.type = "ThrownError";
      expectedError.msg = "effects contract poison";
    };
    "test protected state preserves poison" = {
      expr = (forceThunk protectedState.state).safe && (forceThunk protectedState.value).safe;
      expected = true;
    };
    "test optional field is omitted" = {
      expr = !(normalized.value ? optional);
      expected = true;
    };
    "test explicit null is present" = {
      expr = normalized.value ? nullable && normalized.value.nullable == null;
      expected = true;
    };
    "test defaults are parsed" = {
      expr = normalized.value.defaulted;
      expected = "parsed authored";
    };
    "test unknown values stay opaque and field order is authored" = {
      expr = map (item: item.code) ordered.diagnostics;
      expected = [
        "contract/unknown"
        "contract/b"
        "contract/a"
      ];
    };
    "test malformed field specification fails" = {
      expr =
        rejects
          (
            (schema {
              value = {
                parse = 1;
              };
            })
            null
          ).diagnostics;
      expected = true;
    };
    "test incompatible field specification fails" = {
      expr =
        rejects
          (
            (schema {
              value = {
                parse = validation.success;
                normalize = x: x;
              };
            })
            null
          ).diagnostics;
      expected = true;
    };
    "test aggregate custom rendering is retained" = {
      expr = reporter.render [
        first
        second
      ];
      expected = "errors 2 | custom first | custom second";
    };
    "test summary projection is retained" = {
      expr = krisis.summarizeDiagnostics [
        first
        second
      ];
      expected = {
        total = 2;
        hasErrors = true;
        bySeverity = {
          error = 1;
          warning = 1;
          info = 0;
        };
        byCode = {
          first = 1;
          second = 1;
        };
      };
    };
    "test summary demands only envelope" = {
      expr =
        (krisis.summarizeDiagnostics [
          {
            code = "envelope";
            severity = "info";
            primary = poison;
            context = poison;
          }
        ]).byCode.envelope;
      expected = 1;
    };
    "test empty primary survives round trip" = {
      expr = krisis.effects.finish (items: (builtins.head items).primary == { }) (
        validation.failure [
          (krisis.mkDiagnostic {
            code = "empty-primary";
            severity = "error";
            message = "empty";
            primary = { };
          })
        ]
      );
      expected = true;
    };
    "test explicit null call retains factory primary" = {
      expr =
        (
          (krisis.mkDiagnosticFactory {
            primary.label = "default";
          })
          {
            code = "null";
            message = "null";
            primary = null;
          }
        ).primary.label;
      expected = "default";
    };
    "test explicit null presentation fields are omitted" = {
      expr = builtins.attrNames (
        krisis.mkDiagnostic {
          code = "null";
          severity = "error";
          message = "null";
          primary = null;
          secondaryLabels = null;
          notes = null;
          help = null;
        }
      );
      expected = [
        "code"
        "message"
        "severity"
      ];
    };
    "test code and path helpers retain spellings" = {
      expr =
        krisis.qualifyCode "contract" "code" == "contract/code"
        && krisis.qualifyCode "" "code" == "code"
        &&
          krisis.renderPath [
            "a.b"
            2
            "x"
          ] == "$.\"a.b\"[2].x";
      expected = true;
    };
    "test collector and optional preserve laziness" = {
      expr =
        krisis.collectDiagnostics [
          [ first ]
          [ second ]
        ] == [
          first
          second
        ]
        && krisis.optionalDiagnostic false poison == [ ];
      expected = true;
    };
    "test safe inspection variants retain projections" = {
      expr =
        krisis.safeRender [
          1
          "a"
        ] == "[1,\"a\"]"
        && krisis.safeRenderWith { maxListItems = 0; } [ poison ] == "[] (+1 more)"
        && krisis.safeShape opaque == "{ payload, safe }"
        && lib.hasPrefix "{ payload," (krisis.safeShapeWith { maxAttrs = 1; } opaque)
        &&
          krisis.safeIdentity {
            value = poison;
            label = "label";
            noun = "entry";
          } == "entry 'label'";
      expected = true;
    };
    "test suggestion variants retain nearest" = {
      expr =
        krisis.editDistance "port" "ports" == 1
        &&
          krisis.suggest "port" [
            "ports"
            "host"
          ] == "ports"
        && krisis.suggestWith { maxDistance = 0; } "port" [ "ports" ] == null;
      expected = true;
    };
    "test axiom type adapter retains valid value" = {
      expr =
        (krisis.validateType {
          type = axiom.types.int;
          code = "contract/type";
        })
          1;
      expected = validation.success 1;
    };
    "test axiom type adapter retains failure path" = {
      expr =
        let
          result =
            (krisis.validateType {
              type = axiom.types.int;
              code = "contract/type";
              path = [ "field" ];
              label = "subject";
            })
              false;
        in
        result.diagnostics != [ ]
        && !(result ? value)
        && (builtins.head result.diagnostics).primary.label == "subject"
        && (builtins.head result.diagnostics).context.validation.path == [ "field" ];
      expected = true;
    };
    "test callback old diagnostic enters native report" = {
      expr = (builtins.head emitted.diagnostics).code;
      expected = "first";
    };
    "test public external bookmark lowers" = {
      expr =
        builtins.length bookmarkEntries == 1
        && (builtins.head bookmarkEntries).destination == ".bookmarks/book";
      expected = true;
    };
    "test injected diagnostic factory participates in extension" = {
      expr = hook.message;
      expected = "injected diagnostic";
    };
    "test injected renderer participates in extension" = {
      expr = hook.rendered;
      expected = "injected extension/made";
    };
    "test injected summary participates in extension" = {
      expr = hook.injected;
      expected = true;
    };
    "test injected reporter participates in public report" = {
      expr = publicReport.finish (validation.success 1);
      expected = "injected finish";
    };
    "test selected praxis keeps sibling opaque" = {
      expr = praxis.manifests.selected.version;
      expected = 2;
    };
    "test injected summary participates in praxis" = {
      expr = praxis.diagnosticSummaries.selected.injected;
      expected = true;
    };
  };
in
{
  inherit
    tests
    callbackProbe
    sharedProbe
    projectionProbe
    callbackExceptions
    controlExceptions
    ;
}
