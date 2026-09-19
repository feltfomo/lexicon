{ fx, lexicon }:
{
  testLexiconEntryPoint = {
    expr = lexicon.version;
    expected = "0.0.0";
  };

  testTypesReachable = {
    expr = fx.types.String.check "lexicon";
    expected = true;
  };

  testEffectRuntimeRuns = {
    expr = (fx.run (fx.pure "lexicon") { } null).value;
    expected = "lexicon";
  };
}
// import ./krisis.nix {
  inherit fx;
  inherit (lexicon) krisis;
}
