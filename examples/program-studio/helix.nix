{ program }:
program {
  pkg = pkgs: pkgs.helix;
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  nixos.environment.variables.EDITOR = "hx";
  files = [
    {
      dest = ".config/helix/config.toml";
      src = ./config.toml;
    }
  ];
  # query sources move as one tree while preserving their relative names
  directories = [
    {
      src = ./queries;
      dest = ".config/helix/runtime/queries";
    }
  ];
}
