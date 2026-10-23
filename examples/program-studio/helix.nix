{ lexicon }:
lexicon {
  package = pkgs: pkgs.helix;
  homeManager.imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  nixos = [ { value.environment.variables.EDITOR = "hx"; } ];
  furnish.files = [
    {
      destination = ".config/helix/config.toml";
      source = ./config.toml;
    }
  ];
  furnish.directories = [
    {
      source = ./queries;
      destination = ".config/helix/runtime/queries";
    }
  ];
}
