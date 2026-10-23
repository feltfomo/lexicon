{ lexicon }:
lexicon {
  users = [ "alice" ];
  homeManager.imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  furnish.files = [
    {
      destination = ".config/helix/config.toml";
      source = ./config.toml;
    }
  ];
}
