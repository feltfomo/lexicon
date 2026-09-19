# ports and users are fake, and the emitting code below never changes. what
# moves between tests is the policy the caller installs
{ fx, krisis }:
let
  ports = krisis.vocabulary {
    namespace = "ports";
    codes = {
      unknown-port = {
        message = { rendered, ... }: "unknown port ${rendered.port}";
        help = "declare the port in the host's port map";
      };
      privileged-port = {
        severity = "warning";
        message = { rendered, ... }: "port ${rendered.port} is privileged";
      };
    };
  };

  users = krisis.vocabulary {
    namespace = "users";
    severity = "warning";
    codes.unknown-shell = {
      message =
        {
          rendered,
          suggestion ? null,
          ...
        }:
        "unknown shell ${rendered.shell}"
        + (if suggestion == null then "" else "; did you mean ${suggestion}?");
    };
  };

  badPort =
    port:
    ports.emit.unknown-port {
      at = [
        "services"
        "web"
        "port"
      ];
      context.port = port;
    };

  lowPort = port: ports.emit.privileged-port { context.port = port; };

  badShell =
    shell:
    users.emit.unknown-shell {
      at = [
        "users"
        0
        "shell"
      ];
      context.shell = shell;
      suggestion = krisis.suggest shell [
        "fish"
        "bash"
        "zsh"
      ];
    };

  mixed = fx.seq [
    (lowPort 80)
    (badPort 99999)
    (badShell "fsh")
  ];

  codesOf = result: map (diagnostic: diagnostic.code) result.diagnostics;
in
{
  testCodesAreNamespaced = {
    expr = ports.codes;
    expected = [
      "ports/privileged-port"
      "ports/unknown-port"
    ];
  };

  testUnknownDeclarationFieldIsRejected = {
    expr =
      (builtins.tryEval (
        krisis.vocabulary {
          namespace = "ports";
          codes.typo = {
            message = "x";
            hepl = "y";
          };
        }
      )).success;
    expected = false;
  };

  testBadNamespaceIsRejected = {
    expr =
      (builtins.tryEval (
        krisis.vocabulary {
          namespace = "Ports";
          codes.a.message = "x";
        }
      )).success;
    expected = false;
  };

  testCollectKeepsEveryDiagnostic = {
    expr = codesOf (krisis.run { policy = krisis.policy.collect; } mixed);
    expected = [
      "ports/privileged-port"
      "ports/unknown-port"
      "users/unknown-shell"
    ];
  };

  testCollectSeesTheVocabularySeverityDefault = {
    expr =
      map (diagnostic: diagnostic.severity)
        (krisis.run { policy = krisis.policy.collect; } mixed).diagnostics;
    expected = [
      "warning"
      "error"
      "warning"
    ];
  };

  testStopFirstHaltsOnTheFirstError = {
    expr =
      let
        result = krisis.run { policy = krisis.policy.stopFirst; } mixed;
      in
      {
        inherit (result) halted;
        codes = codesOf result;
      };
    expected = {
      halted = true;
      codes = [
        "ports/privileged-port"
        "ports/unknown-port"
      ];
    };
  };

  testCountTallies = {
    expr = krisis.run { policy = krisis.policy.count; } mixed;
    expected = {
      total = 3;
      bySeverity = {
        error = 1;
        warning = 2;
        info = 0;
      };
      byCode = {
        "ports/privileged-port" = 1;
        "ports/unknown-port" = 1;
        "users/unknown-shell" = 1;
      };
      hasErrors = true;
      halted = false;
      value = null;
    };
  };

  testPrettyRendersLines = {
    expr = (krisis.run { policy = krisis.policy.pretty { }; } (badPort 99999)).report;
    expected = "error: ports/unknown-port at $.services.web.port: unknown port 99999";
  };

  testPrettyLongIncludesHelp = {
    expr = (krisis.run { policy = krisis.policy.pretty { long = true; }; } (badPort 99999)).report;
    expected = ''
      error: ports/unknown-port at $.services.web.port: unknown port 99999
        help: declare the port in the host's port map'';
  };

  testGateStopsTheDependentPhase = {
    expr =
      let
        result = krisis.run { policy = krisis.policy.collect; } (
          fx.bind (krisis.gate (badPort 99999)) (_: lowPort 80)
        );
      in
      {
        inherit (result) halted;
        codes = codesOf result;
      };
    expected = {
      halted = true;
      codes = [ "ports/unknown-port" ];
    };
  };

  testGateLetsWarningsThrough = {
    expr =
      let
        result = krisis.run { policy = krisis.policy.collect; } (
          fx.bind (krisis.gate (lowPort 80)) (_: badShell "fsh")
        );
      in
      {
        inherit (result) halted;
        codes = codesOf result;
      };
    expected = {
      halted = false;
      codes = [
        "ports/privileged-port"
        "users/unknown-shell"
      ];
    };
  };

  testSuggestionReachesTheMessage = {
    expr =
      (builtins.head (krisis.run { policy = krisis.policy.collect; } (badShell "fsh")).diagnostics)
      .message;
    expected = ''unknown shell "fsh"; did you mean fish?'';
  };

  testInterpreterOwnsTheBudget = {
    expr =
      (builtins.head
        (krisis.run {
          policy = krisis.policy.collect;
          rendering = krisis.rendering.bounded { maxStringLength = 4; };
        } (badShell "aaaaaaaaaa")).diagnostics
      ).rendered.shell;
    expected = ''"aaaa…"'';
  };

  testAttrsetsCanBeShownAsShape = {
    expr =
      (builtins.head
        (krisis.run
          {
            policy = krisis.policy.collect;
            rendering = krisis.rendering.bounded { attrsets = "shape"; };
          }
          (badPort {
            a = 1;
            b = 2;
          })
        ).diagnostics
      ).rendered.port;
    expected = "{ a, b }";
  };

  testPoisonValueFallsBack = {
    expr =
      (builtins.head
        (krisis.run { policy = krisis.policy.collect; } (badPort (throw "poison"))).diagnostics
      ).rendered.port;
    expected = "<unrenderable value>";
  };

  testMalformedBudgetIsTheCallersBug = {
    expr = (builtins.tryEval (krisis.rendering.bounded { maxStringLength = "lots"; })).success;
    expected = false;
  };

  testRenderPath = {
    expr = krisis.renderPath [
      "users"
      0
      "shell"
    ];
    expected = "$.users[0].shell";
  };

  testSuggestRespectsTheShortNameRadius = {
    expr = krisis.suggest "abc" [ "wxyz" ];
    expected = null;
  };
}
