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
    "test diagnostic construction and path injection survive effects" = {
      expr =
        map
          (d: {
            inherit (d) notes;
            path = d.primary.label;
          })
          (injectedEncoder.document {
            a = null;
            b = null;
          }).diagnostics;
      expected = [
        {
          notes = [ "injected" ];
          path = "injected $.a";
        }
        {
          notes = [ "injected" ];
          path = "injected $.b";
        }
      ];
    };
    "test native transport keeps opaque fields and context" = {
      expr =
        (builtins.elemAt transported 0).safe
        &&
          builtins.getContext (builtins.elemAt transported 1).value
          == builtins.getContext "${pkgs.coreutils}/bin/true";
      expected = true;
    };
    "test invalid result has no value" = {
      expr = !(encoder.document { bad = null; } ? value);
      expected = true;
    };
    "test raw syntax is deferred" = {
      expr =
        (encoder.document (toml.document "invalid = [")).diagnostics == [ ]
        && (encoder.document { raw = toml.literal "true\ninjected=1"; }).diagnostics == [ ];
      expected = true;
    };
    "test source identity and context pass through" = {
      expr =
        toml.source "path" ./palette.toml == ./palette.toml
        &&
          builtins.getContext (toml.source "string" "${pkgs.coreutils}/bin/true")
          == builtins.getContext "${pkgs.coreutils}/bin/true"
        && (toml.source "derivation" pkgs.hello).drvPath == pkgs.hello.drvPath;
      expected = true;
    };
    "test errors accumulate with structured paths" = {
      expr = diagnostics invalid;
      expected = [
        {
          code = "toml/unsupported-value";
          path = "$.nested[0].function";
        }
        {
          code = "toml/unsupported-value";
          path = "$.nested[0].missing";
        }
      ];
    };
    "test ordinary marker key stays data" = {
      expr = (encoder.document { __lexiconToml = "application"; }).value.value.__lexiconToml.value;
      expected = "application";
    };
    "test constructor precedes derivation classification" = {
      expr = hasError "toml/constructor-field" "$.type" ((toml.literal "1") // { type = "derivation"; });
      expected = true;
    };
    "test constructor unknown field" = {
      expr = hasError "toml/constructor-field" "$.value.typo" {
        value = (toml.literal "1") // {
          typo = true;
        };
      };
      expected = true;
    };
    "test constructor kind is required" = {
      expr = hasError "toml/constructor-kind" "$" (removeAttrs (toml.literal "1") [ "kind" ]);
      expected = true;
    };
    "test constructor kind is closed" = {
      expr = hasError "toml/constructor-kind" "$" ((toml.literal "1") // { kind = "unknown"; });
      expected = true;
    };
    "test constructor value is required" = {
      expr = hasError "toml/constructor-value" "$" (removeAttrs (toml.literal "1") [ "value" ]);
      expected = true;
    };
    "test literal requires text" = {
      expr = hasError "toml/constructor-value" "$.literal" { literal = toml.literal 1; };
      expected = true;
    };
    "test nested document is rejected" = {
      expr = hasError "toml/document-placement" "$.nested[0]" {
        nested = [ (toml.document "a=1") ];
      };
      expected = true;
    };
    "test inline rejects derivations" = {
      expr = hasError "toml/table-value" "$.inline" {
        inline = toml.inline pkgs.hello;
      };
      expected = true;
    };
    "test tables rejects constructors" = {
      expr = hasError "toml/table-value" "$.tables[0]" {
        tables = toml.tables [ (toml.inline { a = 1; }) ];
      };
      expected = true;
    };
    "test table rejection precedes derivation metadata" = {
      expr = hasError "toml/table-value" "$.tables[0]" {
        tables = toml.tables [
          ((toml.literal "1") // { type = throw "forced constructor derivation metadata"; })
        ];
      };
      expected = true;
    };
    "test tables requires list" = {
      expr = hasError "toml/tables-value" "$.tables" { tables = toml.tables { a = 1; }; };
      expected = true;
    };
    "test root must be document" = {
      expr = hasError "toml/document-shape" "$" (toml.literal "1");
      expected = true;
    };
    "test store context survives encoding" = {
      expr =
        builtins.getContext fields.executable.value == builtins.getContext "${pkgs.coreutils}/bin/true"
        && builtins.getContext fields.package.value == builtins.getContext (toString pkgs.hello)
        && builtins.hasContext (builtins.toJSON contextual)
        && fields.source.value == toString ./palette.toml;
      expected = true;
    };
  };
in
tests
