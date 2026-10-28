{
  pkgs,
  lib ? pkgs.lib,
  axiom,
  krisis,
}:
let
  python =
    assert lib.assertMsg (lib.versionAtLeast pkgs.python3Packages.tomlkit.version "0.15.0")
      "toml: TOML Kit >= 0.15.0 is required";
    pkgs.python3.withPackages (p: [ p.tomlkit ]);
  cliRenderer = pkgs.writeText "lexicon-toml-render.nix" ''
    { input }:
    (import ${./render.nix}) (builtins.fromJSON (builtins.readFile input))
  '';
  package = pkgs.writeShellApplication {
    name = "lexicon-toml";
    text = ''exec ${python}/bin/python ${./runtime.py} ${pkgs.nix}/bin/nix-instantiate ${cliRenderer} "$@"'';
  };
  tagged = kind: value: {
    __lexiconToml = x: x;
    inherit kind value;
  };
  encoder = import ./encode.nix { inherit lib axiom krisis; };
  reporter = krisis.mkReporter {
    formatHeader = count: "toml: ${toString count} validation error(s)";
    formatDiagnostic = diagnostic: "  - " + krisis.renderPlain diagnostic;
  };
  # the one rendering path. it yields the document text and the literal
  # fragments generate's builder validates, so render and generate can't drift
  rendered =
    attrs: import ./render.nix (krisis.effects.finishWithReporter reporter (encoder.compile attrs));
  render = attrs: (rendered attrs).text;
  # passthru stays out of the derivation, so exposing what was rendered leaves
  # every generated file's derivation and its consumers' closures unchanged
  generate =
    name: attrs:
    let
      envelope = rendered attrs;
      input = pkgs.writeText "${name}.json" (builtins.toJSON envelope);
    in
    pkgs.runCommand name {
      passthru.rendered = envelope;
    } ''${python}/bin/python ${./runtime.py} "" "" validate ${input} "$out"'';
  source =
    name: value:
    if encoder.isTagged value then
      generate name value
    else if builtins.isAttrs value && !lib.isDerivation value then
      generate name value
    else if builtins.isPath value || builtins.isString value || lib.isDerivation value then
      value
    else
      throw "toml: source ${name} must be attributes, a document, a path or a file derivation";
  merge =
    name:
    {
      sources,
      conflict ? "error",
      arrays ? "replace",
    }:
    assert lib.assertMsg (
      builtins.isList sources && sources != [ ]
    ) "toml: merge requires a nonempty sources list";
    assert lib.assertMsg (builtins.elem conflict [
      "error"
      "first"
      "last"
    ]) "toml: conflict must be error, first or last";
    assert lib.assertMsg (arrays == "replace") "toml: arrays must be replace";
    let
      files = lib.imap0 (i: source "${name}-${toString i}") sources;
    in
    pkgs.runCommand name { } ''
      ${package}/bin/lexicon-toml merge --conflict ${conflict} "$out" ${lib.escapeShellArgs (map toString files)}
    '';
in
{
  inherit
    package
    generate
    render
    merge
    source
    ;
  literal = tagged "literal";
  document = tagged "document";
  inline = tagged "inline";
  tables = tagged "tables";
}
