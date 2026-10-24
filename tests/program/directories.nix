{
  lib,
  axiom,
  krisis,
}:
let
  inherit (krisis) effects;
  inherit (effects.native) validation;
  fields = import ../../src/program/fields.nix { inherit lib axiom; };
  report = import ../../src/program/report.nix { inherit lib axiom krisis; };
  directory = import ../../src/program/directories.nix {
    inherit
      lib
      axiom
      krisis
      fields
      ;
    inherit (report) problem;
    directoryShapeErrors = _: [ ];
    directoryRuleErrors = _: [ ];
  };
  poison = throw "directory effects forced an opaque file value";
  finish = effects.finishComputation (_: throw "unexpected directory diagnostics");
  wrapped = {
    index = [
      "furnish"
      "directories"
      3
    ];
    entry = {
      src = ./fixtures/sample-tree;
      dest = ".config/tree";
    };
    reservedNames = [
      "diagnostics.nix"
      "default.nix"
    ];
  };
  preparation = directory.prewalkDirectory wrapped;
  rules = [
    {
      inherit (wrapped) index;
      entry = {
        names = [ "default.nix" ];
        representation = "writable";
      };
    }
  ];
  expanded = finish (directory.expandComputation wrapped rules [ ] preparation);
  tree = {
    index = 0;
    entry = {
      src = ./fixtures/prunable;
      dest = ".config/pruned";
      exclude = [ "nested" ];
    };
    reservedNames = [ ];
  };
  pruned = finish (directory.expandComputation tree [ ] [ ] (directory.prewalkDirectory tree));
  contextual = tree // {
    entry = tree.entry // {
      src = "${./fixtures/prunable}";
      provenance = poison;
    };
  };
  contextualFiles = finish (
    directory.expandComputation contextual [ ] [ ] (directory.prewalkDirectory contextual)
  );
  invalid = wrapped // {
    reservedNames = [
      "missing"
      "missing"
      "nested/inner.toml"
      "root.nix"
    ];
    entry = tree.entry // {
      exclude = [
        "nested"
        "unknown"
      ];
    };
  };
  diagnostic =
    code:
    report.problem {
      inherit code;
      message = code;
    };
  invalidPreparation = {
    shapeErrors = [ (diagnostic "shape") ];
    sourceErrors = [ (diagnostic "source") ];
    walked = {
      diagnostics = [ (diagnostic "walk") ];
      files = [ "root.nix" ];
      members = [
        "nested"
        "root.nix"
      ];
    };
  };
  invalidThemes = [
    { source = ./fixtures/prunable/nested/inner.toml; }
    { source = ./fixtures/prunable/root.nix; }
  ];
  invalidComputation = directory.expandComputation invalid [ ] invalidThemes invalidPreparation;
  invalidResult = effects.resultOf invalidComputation;
  codes = diagnostics: map (item: item.code) diagnostics;
  callbackProbe =
    let
      shared = builtins.trace "directory-effects shared inventory" (directory.prewalkDirectory tree);
      select =
        destination:
        map (file: file.dest) (
          finish (
            directory.expandComputation (
              tree
              // {
                entry = tree.entry // {
                  dest = destination;
                };
              }
            ) [ ] [ ] shared
          )
        );
    in
    {
      first = select ".config/first";
      second = select ".config/second";
    };
in
{
  inherit callbackProbe;
  tests = {
    directory-native-expansion-reserves-inactive-overrides =
      map (file: file.dest) expanded == [
        ".config/tree/safe-render.nix"
        ".config/tree/default.nix"
      ]
      && (builtins.elemAt expanded 1).representation == "writable";
    directory-native-expansion-preserves-path-sources = builtins.all (
      file: builtins.isPath file.src
    ) expanded;
    directory-native-expansion-prunes-before-recursion =
      map (file: file.dest) pruned == [ ".config/pruned/root.nix" ]
      &&
        (directory.prewalkDirectory tree).walked.members == [
          "nested"
          "root.nix"
        ];
    directory-native-expansion-preserves-context-and-opaque-lifecycle-values =
      map (file: file.dest) contextualFiles == [ ".config/pruned/root.nix" ]
      && builtins.hasContext (builtins.head contextualFiles).src;
    directory-native-diagnostics-retain-order-and-origin =
      codes invalidResult.diagnostics == [
        "program/shape"
        "program/source"
        "program/walk"
        "program/directory-file-duplicate"
        "program/directory-exclude-unknown"
        "program/directory-file-unknown"
        "program/directory-file-excluded"
        "program/directory-theme-excluded"
        "program/directory-file-themed"
      ]
      && (builtins.elemAt invalidResult.diagnostics 3).primary.label == "$.furnish.directories[3]";
    directory-native-failure-suppresses-dependent-files =
      effects.finishComputation codes (validation.andThen (_: poison) invalidComputation)
      == codes invalidResult.diagnostics
      && !(invalidResult ? value);
    directory-native-and-pure-projections-agree =
      map (file: file.dest) expanded
      == map (file: file.dest) (directory.expandDirectory wrapped rules [ ] preparation).files
      &&
        invalidResult.diagnostics
        == (directory.expandDirectory invalid [ ] invalidThemes invalidPreparation).errors;
    directory-prefix-exclusion-keeps-short-circuiting =
      directory.excludedBy [ "nested" poison ] "nested/inner.toml"
      && !(directory.excludedBy [ "nested" ] "nested-other/inner.toml");
  };
}
