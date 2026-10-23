{ lexicon }:
lexicon {
  theme = {
    id = "paperkite";
    renderers.noctalia = {
      source = ./palette.tmpl;
      output = ".config/paperkite/colors.conf";
      native.compare_to = "dark";
    };
  };
}
