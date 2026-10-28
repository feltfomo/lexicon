# the public render against what generate rendered for its builder, read from
# its passthru. both take the same value through the public surface, so the
# comparison needs no build
{ pkgs, lexicon }:
let
  inherit (pkgs) lib;
  toml = lexicon.lib.toml { inherit pkgs; };
  rendering = import ./rendering.nix {
    inherit lib;
    context = "${pkgs.coreutils}/bin/true";
  };

  # the builder validates this envelope and writes its text unchanged
  written = value: (toml.generate "rendered.toml" value).rendered.text;

  agrees =
    name:
    let
      value = rendering.fixtures.${name}.expected;
    in
    {
      "test render matches what generate writes for the ${name} fixture" = {
        expr = toml.render value == written value;
        expected = true;
      };
    };
in
lib.foldl' (tests: name: tests // agrees name) {
  "test render keeps store context" = {
    expr = builtins.getContext (toml.render { executable = "${pkgs.coreutils}/bin/true"; });
    expected = builtins.getContext "${pkgs.coreutils}/bin/true";
  };

  # literals are checked by generate's builder, so render passes malformed text through
  "test render does no build-time validation" = {
    expr = toml.render { value = toml.literal "broken=["; };
    expected = "\"value\" = broken=[\n\n";
  };

  "test render reports encoder errors like generate" = {
    expr = toml.render { bad = null; };
    expectedError.type = "ThrownError";
    expectedError.msg = "toml: 1 validation error";
  };
} (builtins.attrNames rendering.fixtures)
