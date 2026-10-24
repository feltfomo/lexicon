{ pkgs, lexicon }:
let
  inherit (pkgs) lib;
  axiom = lexicon.inputs.axiom.lib.axiom { inherit lib; };
  inherit
    (import ../../src/dependencies.nix {
      inherit lib axiom;
      krisisSource = lexicon.inputs.krisis;
    })
    krisis
    ;
  encoder = import ../../src/toml/encode.nix { inherit lib axiom krisis; };
  injectedEncoder = import ../../src/toml/encode.nix {
    inherit lib axiom;
    krisis = krisis // {
      mkDiagnosticFactory =
        options: args: (krisis.mkDiagnosticFactory options args) // { notes = [ "injected" ]; };
      renderPath = path: "injected " + krisis.renderPath path;
    };
  };
  toml = lexicon.lib.toml { inherit pkgs; };
  diagnostics =
    value:
    map (entry: {
      inherit (entry) code;
      path = entry.primary.label;
    }) (encoder.document value).diagnostics;
  hasError =
    code: path: value:
    builtins.elem { inherit code path; } (diagnostics value);
  contextual =
    (encoder.document {
      executable = "${pkgs.coreutils}/bin/true";
      package = pkgs.hello;
      source = ./palette.toml;
    }).value;
  fields = contextual.value;
  transported = krisis.effects.finishComputation (_: throw "unexpected transport rejection") (
    krisis.effects.native.validation.all [
      (krisis.effects.accept {
        safe = true;
        opaque = throw "forced opaque input";
      })
      (krisis.effects.accept {
        value = "${pkgs.coreutils}/bin/true";
        opaque = throw "forced opaque output";
      })
    ]
  );
  invalid = {
    nested = [
      {
        missing = null;
        function = _: throw "forced invalid function";
      }
    ];
  };
  tests = {
    diagnostic-construction-and-path-injection-survive-effects =
      map
        (d: {
          inherit (d) notes;
          path = d.primary.label;
        })
        (injectedEncoder.document {
          a = null;
          b = null;
        }).diagnostics == [
        {
          notes = [ "injected" ];
          path = "injected $.a";
        }
        {
          notes = [ "injected" ];
          path = "injected $.b";
        }
      ];
    native-transport-keeps-opaque-fields-and-context =
      (builtins.elemAt transported 0).safe
      &&
        builtins.getContext (builtins.elemAt transported 1).value
        == builtins.getContext "${pkgs.coreutils}/bin/true";
    invalid-result-has-no-value = !(encoder.document { bad = null; } ? value);
    raw-syntax-is-deferred =
      (encoder.document (toml.document "invalid = [")).diagnostics == [ ]
      && (encoder.document { raw = toml.literal "true\ninjected=1"; }).diagnostics == [ ];
    source-identity-and-context-pass-through =
      toml.source "path" ./palette.toml == ./palette.toml
      &&
        builtins.getContext (toml.source "string" "${pkgs.coreutils}/bin/true")
        == builtins.getContext "${pkgs.coreutils}/bin/true"
      && (toml.source "derivation" pkgs.hello).drvPath == pkgs.hello.drvPath;
    errors-accumulate-with-structured-paths =
      diagnostics invalid == [
        {
          code = "toml/unsupported-value";
          path = "$.nested[0].function";
        }
        {
          code = "toml/unsupported-value";
          path = "$.nested[0].missing";
        }
      ];
    ordinary-marker-key-stays-data =
      (encoder.document { __lexiconToml = "application"; }).value.value.__lexiconToml.value
      == "application";
    constructor-precedes-derivation-classification = hasError "toml/constructor-field" "$.type" (
      (toml.literal "1") // { type = "derivation"; }
    );
    constructor-unknown-field = hasError "toml/constructor-field" "$.value.typo" {
      value = (toml.literal "1") // {
        typo = true;
      };
    };
    constructor-kind-is-required = hasError "toml/constructor-kind" "$" (
      removeAttrs (toml.literal "1") [ "kind" ]
    );
    constructor-kind-is-closed = hasError "toml/constructor-kind" "$" (
      (toml.literal "1") // { kind = "unknown"; }
    );
    constructor-value-is-required = hasError "toml/constructor-value" "$" (
      removeAttrs (toml.literal "1") [ "value" ]
    );
    literal-requires-text = hasError "toml/constructor-value" "$.literal" { literal = toml.literal 1; };
    nested-document-is-rejected = hasError "toml/document-placement" "$.nested[0]" {
      nested = [ (toml.document "a=1") ];
    };
    inline-rejects-derivations = hasError "toml/table-value" "$.inline" {
      inline = toml.inline pkgs.hello;
    };
    tables-rejects-constructors = hasError "toml/table-value" "$.tables[0]" {
      tables = toml.tables [ (toml.inline { a = 1; }) ];
    };
    table-rejection-precedes-derivation-metadata = hasError "toml/table-value" "$.tables[0]" {
      tables = toml.tables [
        ((toml.literal "1") // { type = throw "forced constructor derivation metadata"; })
      ];
    };
    tables-requires-list = hasError "toml/tables-value" "$.tables" { tables = toml.tables { a = 1; }; };
    root-must-be-document = hasError "toml/document-shape" "$" (toml.literal "1");
    store-context-survives-encoding =
      builtins.getContext fields.executable.value == builtins.getContext "${pkgs.coreutils}/bin/true"
      && builtins.getContext fields.package.value == builtins.getContext (toString pkgs.hello)
      && builtins.hasContext (builtins.toJSON contextual)
      && fields.source.value == toString ./palette.toml;
  };
  failing = builtins.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in
if failing == [ ] then
  true
else
  throw "TOML encoding tests failed: ${lib.concatStringsSep ", " failing}"
