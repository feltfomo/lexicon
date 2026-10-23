{ lexicon }:
lexicon {
  users = [ "river" ];
  furnish.files = [
    {
      destination = ".config/paperkite/den.conf";
      source = ./settings.conf;
    }
  ];
}
