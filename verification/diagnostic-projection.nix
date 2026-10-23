{ krisis, axiom }:
let
  diagnostic =
    (krisis.mkDiagnosticFactory {
      codePrefix = "projection";
      primary.source = "authored.nix";
    })
      {
        code = "record";
        message = "invalid record";
        primary.label = "record";
        notes = [ "note" ];
        help = "help";
        context = throw "diagnostic projection forced context";
      };
  reporter = krisis.mkReporter {
    formatHeader = count: "errors ${toString count}";
    formatDiagnostic = item: "custom ${item.code}";
    separator = " | ";
  };
in
{
  exports = builtins.filter (name: name != "effects") (builtins.attrNames krisis);
  record = removeAttrs diagnostic [ "context" ];
  plain = krisis.renderPlain diagnostic;
  aggregate = reporter.render [
    diagnostic
    diagnostic
  ];
  summary = krisis.summarizeDiagnostics [ diagnostic ];
  path = krisis.renderPath [
    "a.b"
    0
    ""
  ];
  inspected = {
    value = krisis.safeRenderWith { maxListItems = 1; } [
      "first"
      (throw "omitted")
    ];
    shape = krisis.safeShapeWith { maxAttrs = 1; } {
      a = throw "opaque";
      b = null;
    };
    identity = krisis.safeIdentity {
      value = throw "opaque identity";
      label = "authored";
    };
  };
  suggestions = {
    nearest = krisis.suggest "chec" [
      "check"
      "help"
    ];
    bounded = krisis.suggestWith { maxDistance = 0; } "chec" [ "check" ];
    distance = krisis.editDistance "check" "chec";
  };
  typed =
    (krisis.validateType {
      type = axiom.types.string;
      code = "projection/type";
    })
      1;
}
