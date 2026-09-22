# a home, so it lands in the person's own configuration
{ home, ... }:
home {
  homeManager = {
    programs.git = {
      enable = true;
      extraConfig.init.defaultBranch = "main";
    };
  };
}
