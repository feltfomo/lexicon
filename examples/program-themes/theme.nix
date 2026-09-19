{ program }:
program {
  theme = {
    id = "paperkite";
    renderers.noctalia = {
      source = ./palette.tmpl;
      output = ".config/paperkite/colors.conf";
      # native fields become renderer-specific registration data
      native.compare_to = "dark";
    };
  };
}
