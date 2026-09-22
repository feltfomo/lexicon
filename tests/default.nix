{
  lib,
  fx,
  lexicon,
  mkLexicon,
}:
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
// import ./koseki.nix {
  inherit
    lib
    fx
    lexicon
    mkLexicon
    ;
}
// import ./kata.nix {
  inherit lib lexicon;
}
// import ./walk.nix {
  inherit lib lexicon;
}
// import ./emit.nix {
  inherit lib lexicon;
}
// import ./introspect.nix {
  inherit lib lexicon;
}
