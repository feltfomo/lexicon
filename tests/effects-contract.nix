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
  callbackExceptions = {
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
    structural-terminal-projection-does-not-replace-prepared-entry =
      (builtins.head (projectedDeclaration.homeManager args).imports).safe;
    shared-validation-retains-diagnostics-and-suppresses-dependent-work =
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
    shared-validation-transports-opaque-successes =
      let
        computation = krisis.effects.share (krisis.effects.accept opaque);
      in
      (krisis.effects.finishComputation (_: poison) computation).safe
      && (krisis.effects.finishComputation (_: poison) computation).safe;
    string-and-record-diagnostics-recover-in-order =
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
        ) == [
        "authored string"
        first.code
      ];
    composed-checked-values-protect-arbitrary-payloads =
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
    old-location-poison-stays-opaque =
      (krisis.effects.run {
        diagnostics = [
          {
            code = "opaque";
            severity = "warning";
            message = poison;
            primary = poison;
          }
        ];
      }).summary.total == 1;
    empty-old-primary-is-absent-in-native-presentation =
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
      )).primary == null;
    malformed-inspection-options-fail-before-payload = rejects controlExceptions.inspection;
    malformed-summary-input-fails = rejects controlExceptions.summary;
    injected-axiom-identity-participates =
      (builtins.head (identityDeclaration.homeManager args).imports).hook.identity == "injected identity";
    shared-handler-runs-remain-isolated =
      emitted.summary.total == 2
      && (krisis.effects.run (validation.success true)).summary.total == 0
      && (krisis.effects.run (validation.success true)).outcome._con == "Success";
    malformed-success-result-is-rejected = rejects (krisis.effects.run { diagnostics = [ ]; }).outcome;
    malformed-diagnostics-result-is-rejected =
      rejects
        (krisis.effects.run { diagnostics = { }; }).outcome;
    independent-diagnostics-stay-ordered =
      map (item: item.code) (run independent).diagnostics == [
        "first"
        "second"
      ];
    dependent-callback-is-suppressed = (checked skipped)._con == "Invalid";
    invalid-has-no-value = builtins.attrNames (checked skipped) == [ "_con" ];
    failure-has-no-value = builtins.attrNames emitted.outcome == [ "_con" ];
    failure-constructor-is-explicit = emitted.outcome._con == "Failure";
    valid-and-success-eliminate-through-carriers =
      transported.outcome._con == "Success"
      && (forceThunk transported.outcome.value)._con == "Valid"
      && (forceThunk (forceThunk transported.outcome.value).value).safe;
    returned-poison-stays-opaque =
      builtins.attrNames (forceThunk (forceThunk transported.outcome.value).value) == [
        "payload"
        "safe"
      ];
    poisoned-input-state-and-summary-stay-opaque =
      deferred.summary.total == 1 && deferred.summary.byCode.opaque == 1;
    old-diagnostic-recovery-stays-opaque =
      krisis.effects.finish (items: builtins.attrNames (builtins.head items)) {
        diagnostics = [
          {
            code = "opaque";
            severity = "error";
            message = poison;
            context = poison;
          }
        ];
      } == [
        "code"
        "context"
        "message"
        "severity"
      ];
    nested-and-sibling-scopes-restore =
      map (item: item.code) scoped.diagnostics == [
        "root/first"
        "nested/second"
        "root/third"
        "sibling/fourth"
      ];
    scoped-poison-stays-opaque = scoped.summary.total == 4;
    handler-collisions-fail = rejects (
      native.report.run {
        handlers."krisis.emit" = poison;
      } (fx.pure 1)
    );
    unhandled-effects-fail = rejects (run (fx.send "effects-contract.unhandled" null));
    raw-state-control-forces-poison = rejects rawState.value;
    protected-state-preserves-poison =
      (forceThunk protectedState.state).safe && (forceThunk protectedState.value).safe;
    optional-field-is-omitted = !(normalized.value ? optional);
    explicit-null-is-present = normalized.value ? nullable && normalized.value.nullable == null;
    defaults-are-parsed = normalized.value.defaulted == "parsed authored";
    unknown-values-stay-opaque-and-field-order-is-authored =
      map (item: item.code) ordered.diagnostics == [
        "contract/unknown"
        "contract/b"
        "contract/a"
      ];
    malformed-field-specification-fails =
      rejects
        (
          (schema {
            value = {
              parse = 1;
            };
          })
          null
        ).diagnostics;
    incompatible-field-specification-fails =
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
    aggregate-custom-rendering-is-retained =
      reporter.render [
        first
        second
      ] == "errors 2 | custom first | custom second";
    summary-projection-is-retained =
      krisis.summarizeDiagnostics [
        first
        second
      ] == {
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
    summary-demands-only-envelope =
      (krisis.summarizeDiagnostics [
        {
          code = "envelope";
          severity = "info";
          primary = poison;
          context = poison;
        }
      ]).byCode.envelope == 1;
    empty-primary-survives-round-trip =
      krisis.effects.finish (items: (builtins.head items).primary == { })
        (
          validation.failure [
            (krisis.mkDiagnostic {
              code = "empty-primary";
              severity = "error";
              message = "empty";
              primary = { };
            })
          ]
        );
    explicit-null-call-retains-factory-primary =
      (
        (krisis.mkDiagnosticFactory {
          primary.label = "default";
        })
        {
          code = "null";
          message = "null";
          primary = null;
        }
      ).primary.label == "default";
    explicit-null-presentation-fields-are-omitted =
      builtins.attrNames (
        krisis.mkDiagnostic {
          code = "null";
          severity = "error";
          message = "null";
          primary = null;
          secondaryLabels = null;
          notes = null;
          help = null;
        }
      ) == [
        "code"
        "message"
        "severity"
      ];
    code-and-path-helpers-retain-spellings =
      krisis.qualifyCode "contract" "code" == "contract/code"
      && krisis.qualifyCode "" "code" == "code"
      &&
        krisis.renderPath [
          "a.b"
          2
          "x"
        ] == "$.\"a.b\"[2].x";
    collector-and-optional-preserve-laziness =
      krisis.collectDiagnostics [
        [ first ]
        [ second ]
      ] == [
        first
        second
      ]
      && krisis.optionalDiagnostic false poison == [ ];
    safe-inspection-variants-retain-projections =
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
    suggestion-variants-retain-nearest =
      krisis.editDistance "port" "ports" == 1
      &&
        krisis.suggest "port" [
          "ports"
          "host"
        ] == "ports"
      && krisis.suggestWith { maxDistance = 0; } "port" [ "ports" ] == null;
    axiom-type-adapter-retains-valid-value =
      (krisis.validateType {
        type = axiom.types.int;
        code = "contract/type";
      })
        1 == validation.success 1;
    axiom-type-adapter-retains-failure-path =
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
    callback-old-diagnostic-enters-native-report = (builtins.head emitted.diagnostics).code == "first";
    public-external-bookmark-lowers =
      builtins.length bookmarkEntries == 1
      && (builtins.head bookmarkEntries).destination == ".bookmarks/book";
    injected-diagnostic-factory-participates-in-extension = hook.message == "injected diagnostic";
    injected-renderer-participates-in-extension = hook.rendered == "injected extension/made";
    injected-summary-participates-in-extension = hook.injected;
    injected-reporter-participates-in-public-report =
      publicReport.finish (validation.success 1) == "injected finish";
    selected-praxis-keeps-sibling-opaque = praxis.manifests.selected.version == 2;
    injected-summary-participates-in-praxis = praxis.diagnosticSummaries.selected.injected;
  };
  failing = builtins.attrNames (lib.filterAttrs (_: pass: !pass) tests);
  ok =
    if failing == [ ] then
      true
    else
      throw "effects contract tests failed ${lib.concatStringsSep ", " failing}";
in
{
  inherit
    tests
    ok
    callbackProbe
    sharedProbe
    callbackExceptions
    controlExceptions
    ;
}
