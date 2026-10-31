{
  lib,
  pkgs,
  axiom,
  krisis,
  lexicon,
}:
let
  fields = import ../../src/program/fields.nix { inherit lib axiom; };
  report = import ../../src/program/report.nix { inherit lib axiom krisis; };
  contract = import ../../src/furnish/contract.nix { inherit lib axiom; };
  template = import ../../src/program/theme/template.nix { inherit lib; };
  dialects = import ../../src/program/theme/dialects.nix { inherit lib; };
  themeWith =
    reporter:
    import ../../src/program/theme {
      inherit
        lib
        axiom
        krisis
        contract
        reporter
        ;
      inherit (fields)
        unknownFields
        validRelativePath
        validBaseName
        validSubdir
        ;
      inherit (report) duplicateValues problem;
    };
  theme = themeWith report.reporter;
  capturing = themeWith (
    report.reporter
    // {
      checked = diagnostics: _: diagnostics;
    }
  );
  capturedPkgs = pkgs // {
    writeText = name: text: builtins.toFile name text;
  };

  entryOf =
    renderer: shared:
    theme.normalizeEntry {
      inherit renderer;
      blockId = "app";
      entry = theme.effectiveEntry shared { };
    };
  portable = text: {
    template = text;
    placedAs = "palette";
    output = ".config/app/palette";
  };
  renderedAs =
    renderer: text:
    builtins.readFile
      (builtins.head (theme.themeFiles [ (entryOf renderer (portable text)) ] capturedPkgs)).src;
  diagnosticsOf =
    text: capturing.themeFiles [ (entryOf "noctalia" (portable text)) ] (throw "reached a package");
  problemCodes =
    declaration: map (problem: problem.code) (theme.themeTemplateErrors "theme" declaration);

  target = {
    host = {
      name = "workstation";
      system = pkgs.stdenv.hostPlatform.system;
    };
    user = {
      name = "alice";
      home = "/srv/alice";
    };
  };
  seedDestinations =
    declaration:
    let
      result = ((lexicon.lib.lexicon.forTarget { inherit target; }) { theme = declaration; }).nixos {
        inherit lib;
        pkgs = capturedPkgs;
        config = {
          networking.hostName = "workstation";
          lexicon.furnish.declarations = [ { } ];
        };
      };
      declarations =
        (builtins.head (
          builtins.filter (module: builtins.isAttrs module && module ? lexicon) result.imports
        )).lexicon.furnish.declarations;
    in
    builtins.filter (lib.hasInfix "templates") (map (entry: entry.destination) declarations);

  tests = {
    "test matugen renders a token with its hash" = {
      expr = renderedAs "noctalia" "a {{ onPrimaryContainer }} b";
      expected = "a {{ colors.on_primary_container.default.hex }} b";
    };
    "test matugen renders bare mode and filters" = {
      expr = renderedAs "dms" "{{ primary.dark.bare | set_hue: 45 }}";
      expected = "{{ colors.primary.dark.hex_stripped | set_hue: 45 }}";
    };
    "test matugen synthesizes roles it lacks" = {
      expr = renderedAs "noctalia" "{{ warning.light }}";
      expected = "{{ colors.primary.light.hex | set_hue: 45 | set_saturation: 60 }}";
    };
    "test matugen maps the terminal palette onto material roles" = {
      expr = renderedAs "noctalia" "{{ term13 }}";
      expected = "{{ colors.on_primary_container.default.hex }}";
    };
    "test caelestia adds the hash its hex form lacks" = {
      expr = renderedAs "caelestia" "{{ surfaceDim }} {{ surfaceDim.bare }}";
      expected = "#{{ surfaceDim.hex }} {{ surfaceDim.hex }}";
    };
    "test caelestia resolves modes and filters to the active color" = {
      expr = renderedAs "caelestia" "{{ primary.dark }} {{ primary.light | set_hue: 45 }}";
      expected = "#{{ primary.hex }} #{{ primary.hex }}";
    };
    "test caelestia resolves roles through its terminal palette" = {
      expr = renderedAs "caelestia" "{{ success }} {{ warning }}";
      expected = "#{{ term2.hex }} #{{ term3.hex }}";
    };
    "test template syntax around placeholders stays literal" = {
      expr = renderedAs "noctalia" "a { b: {{ primary }}; } {literal}";
      expected = "a { b: {{ colors.primary.default.hex }}; } {literal}";
    };
    "test every token renders in every dialect" = {
      expr = builtins.all (
        dialect:
        builtins.all (
          token:
          lib.hasPrefix "{{" (
            lib.removePrefix "#" (template.render dialect (template.parse "{{ ${token} }}"))
          )
        ) template.tokens
      ) (builtins.attrValues dialects);
      expected = true;
    };
    "test a misspelled token reports through krisis with a suggestion" = {
      expr = map (problem: {
        inherit (problem) code help;
        label = problem.primary.label;
      }) (diagnosticsOf "{{ primry }}");
      expected = [
        {
          code = "program/theme-token-unknown";
          help = "did you mean \"primary\"?";
          label = "theme.noctalia.app";
        }
      ];
    };
    "test a native token is rejected instead of leaking to another shell" = {
      expr = map (problem: problem.code) (diagnosticsOf "{{ colors.primary.default.hex }}");
      expected = [
        "program/theme-token-unknown"
        "program/theme-token-modifier"
        "program/theme-token-modifier"
        "program/theme-token-modifier"
      ];
    };
    "test repeated placeholders report once" = {
      expr = builtins.length (diagnosticsOf "{{ nope }} {{ nope }}");
      expected = 1;
    };
    "test two modes are rejected" = {
      expr = map (problem: problem.code) (diagnosticsOf "{{ primary.dark.light }}");
      expected = [ "program/theme-token-mode" ];
    };
    "test native entries skip token validation" = {
      expr =
        capturing.themeFiles [
          (theme.normalizeEntry {
            renderer = "noctalia";
            blockId = "app";
            entry = {
              source = throw "validated a native source";
              placedAs = "palette";
              output = ".config/app/palette";
            };
          })
        ] (throw "reached a package")
        |> map (file: file.dest);
      expected = [
        ".config/noctalia/templates/app/palette"
        ".config/noctalia/app.toml"
      ];
    };
    "test a template reaches every shell without renderers" = {
      expr = builtins.length (seedDestinations {
        id = "app";
        template = "{{ primary }}";
        placedAs = "palette";
        output = ".config/app/palette";
      });
      expected = builtins.length theme.themeBackends;
    };
    "test a renderer source replaces the template for that shell only" = {
      expr =
        let
          override = {
            source = ./fixtures/sample-tree/safe-render.nix;
          };
          shared = portable "{{ primary }}";
        in
        {
          overridden = (theme.effectiveEntry shared override).syntax or "native";
          kept = (theme.effectiveEntry shared { }).syntax;
        };
      expected = {
        overridden = "native";
        kept = "portable";
      };
    };
    "test source and template in one layer conflict" = {
      expr = problemCodes (
        portable "{{ primary }}"
        // {
          source = ./fixtures/sample-tree/safe-render.nix;
        }
      );
      expected = [ "program/theme-template-source-conflict" ];
    };
    "test a template string needs a name" = {
      expr = problemCodes {
        template = "{{ primary }}";
        output = ".config/app/palette";
      };
      expected = [ "program/theme-template-name" ];
    };
    "test a template path takes its name from the file" = {
      expr = problemCodes {
        template = ./fixtures/sample-tree/safe-render.nix;
        output = ".config/app/palette";
      };
      expected = [ ];
    };
    "test transform receives the compiled file" = {
      expr =
        let
          entry = entryOf "caelestia" (
            portable "{{ primary }}"
            // {
              transform = compiled: builtins.toFile "wrapped" "wrapped ${builtins.readFile compiled}";
            }
          );
        in
        builtins.readFile (builtins.head (theme.themeFiles [ entry ] capturedPkgs)).src;
      expected = "wrapped #{{ primary.hex }}";
    };
    "test transform needs a template" = {
      expr = problemCodes {
        source = ./fixtures/sample-tree/safe-render.nix;
        renderers.noctalia.transform = lib.id;
        output = ".config/app/palette";
      };
      expected = [ "program/theme-transform-source" ];
    };
    "test a declaration without source or template still needs renderers" = {
      expr = problemCodes { output = ".config/app/palette"; };
      expected = [ "program/theme-renderers-shape" ];
    };
  };
in
{
  inherit tests;
}
