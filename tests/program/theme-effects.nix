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
  theme = import ../../src/program/theme {
    inherit
      lib
      axiom
      krisis
      contract
      ;
    inherit (fields)
      unknownFields
      validRelativePath
      validBaseName
      validSubdir
      ;
    inherit (report) duplicateValues problem reporter;
  };
  normalize =
    renderer: blockId: entry:
    theme.normalizeEntry { inherit renderer blockId entry; };
  poisoned =
    renderer: blockId:
    normalize renderer blockId {
      source = throw "theme effects forced a template source";
      placedAs = "palette.tmpl";
      output = ".config/${blockId}/palette";
    };
  duplicate = (poisoned "caelestia" "duplicate") // {
    native = throw "theme effects checked native fields after a duplicate";
  };
  capturingTheme = import ../../src/program/theme {
    inherit
      lib
      axiom
      krisis
      contract
      ;
    inherit (fields)
      unknownFields
      validRelativePath
      validBaseName
      validSubdir
      ;
    inherit (report) duplicateValues problem;
    reporter = report.reporter // {
      checked = diagnostics: _: diagnostics;
    };
  };
  invalid = capturingTheme.themeFiles [
    duplicate
    duplicate
    ((poisoned "caelestia" "unsupported") // { native.invalid = true; })
  ] (throw "theme effects constructed an adapter package during diagnostics");
  protected = theme.themeFiles [
    (poisoned "noctalia" "first")
    (poisoned "noctalia" "second")
  ] (throw "theme effects demanded a generator during file projection");
  principal = {
    authority = {
      scope = "user";
      identity = "alice";
    };
    managedRoot = "/srv/alice";
  };
  tag =
    entry:
    entry
    // {
      inherit principal;
      filesystemNamespace = "x86_64-linux/workstation";
    };
  matugenEntry =
    id:
    tag (
      normalize "dms" id {
        source = throw "theme effects demanded a Matugen seed during aggregation";
        placedAs = "palette.tmpl";
        output = ".config/${id}/palette";
        reload = "reload-${id}";
        native = {
          input_path = "ignored input";
          output_path = "ignored output";
          post_hook = "ignored hook";
          compare_to = "dark";
        };
      }
    );
  capturedPkgs = pkgs // {
    formats.toml = _: {
      generate = name: value: builtins.toFile name (builtins.toJSON value);
    };
  };
  evaluateMatugen =
    entries:
    lib.evalModules {
      specialArgs.pkgs = capturedPkgs;
      modules = [
        (import ../../src/program/theme/matugen-runtime.nix { inherit axiom krisis; })
        ({ lib, ... }: {
          options.lexicon.furnish.declarations = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          config.lexicon.theme.matugen.entries = entries;
        })
      ];
    };
  aggregated =
    (evaluateMatugen [
      (matugenEntry "first")
      (matugenEntry "second")
    ]).config.lexicon.furnish.declarations;
  aggregate = builtins.head aggregated;
  generated = builtins.fromJSON (builtins.readFile aggregate.source.value);
  duplicateAggregation = builtins.tryEval (
    builtins.length
      (evaluateMatugen [
        (matugenEntry "duplicate")
        (matugenEntry "duplicate")
      ]).config.lexicon.furnish.declarations
  );
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
  common = {
    theme = {
      id = "equivalent";
      source = ./fixtures/sample-tree/safe-render.nix;
      output = ".config/equivalent/palette";
      reload = "reload-equivalent";
      renderers.noctalia.sharedWith = [ "dms" ];
    };
  };
  canonical = (lexicon.lib.lexicon.forTarget { inherit target; }) common;
  legacy = (lexicon.lib.programDirect { inherit target; }) common;
  selectedFiles =
    aspect:
    let
      result = aspect.nixos {
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
    map (entry: {
      inherit (entry) destination representation authority;
      source = toString entry.source.value;
      onConflict = entry.onConflict or "error";
    }) declarations;
  cases = {
    recovering-theme-checked-retains-each-group-diagnostics =
      map (diagnostic: diagnostic.code) invalid == [
        "program/theme-registration-duplicate"
        "program/theme-native-unsupported"
      ]
      &&
        map (diagnostic: diagnostic.primary.label) invalid == [
          "theme.caelestia.duplicate"
          "theme.caelestia.unsupported"
        ];
    theme-file-transport-preserves-opaque-sources-and-generators =
      map (entry: entry.dest) protected == [
        ".config/noctalia/templates/first/palette.tmpl"
        ".config/noctalia/first.toml"
        ".config/noctalia/templates/second/palette.tmpl"
        ".config/noctalia/second.toml"
      ];
    template-defaults-retain-runtime-wins =
      (builtins.head protected).representation == "writable"
      && (builtins.head protected).onConflict == "runtime-wins";
    matugen-aggregates-blocks-with-original-principal =
      builtins.length aggregated == 1
      && aggregate.destination == ".config/matugen/config.toml"
      && aggregate.authority == principal.authority
      && aggregate.managedRoot == principal.managedRoot
      &&
        builtins.attrNames generated.templates == [
          "first"
          "second"
        ];
    matugen-generated-fields-and-reload-override-native =
      generated.templates.first == {
        input_path = "/srv/alice/.config/matugen/dms/templates/first/palette.tmpl";
        output_path = "/srv/alice/.config/first/palette";
        post_hook = "reload-first";
        compare_to = "dark";
      };
    matugen-rejects-cross-block-registration-collisions = !duplicateAggregation.success;
    canonical-and-legacy-theme-files-are-equivalent = selectedFiles canonical == selectedFiles legacy;
  };
in
{
  inherit cases;
  ok = builtins.all (value: value) (builtins.attrValues cases);
}
