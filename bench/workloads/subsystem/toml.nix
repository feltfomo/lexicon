# public toml rendering over size records, each with an integer, a precise
# float, a contextual executable string, a heterogeneous array and a literal.
# the projection is the rendered document text, which stays comparable when
# the renderer's implementation changes. generate renders through the same
# path and adds only build-time validation, which no evaluation workload runs
{
  api,
  pkgs,
  records,
  ...
}:
let
  toml = api.toml { inherit pkgs; };
  executable = "${pkgs.coreutils}/bin/true";
  text = toml.render (
    records (_: {
      count = 1;
      precise = 1.2345678901234567;
      inherit executable;
      values = [
        true
        "two"
        3
      ];
      spelling = toml.literal "0x1_0";
    })
  );
in
{
  # the executable keeps its context through rendering, but its store hash moves
  # with nixpkgs, so the projection names it instead
  generate =
    builtins.replaceStrings
      [ (builtins.unsafeDiscardStringContext executable) ]
      [ "coreutils/bin/true" ]
      text;
}
