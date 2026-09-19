{ lexicon, system }:
# one fixed target keeps ordinary application declarations claim-free
lexicon.lib.programDirect {
  target = {
    host = {
      name = "studio";
      inherit system;
    };
    user.name = "river";
  };
}
