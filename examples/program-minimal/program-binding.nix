{ lexicon, system }:
lexicon.lib.lexicon.forTarget {
  target = {
    host = {
      name = "studio";
      inherit system;
    };
    user.name = "river";
  };
}
