{ program }:
program {
  users = [ "alice" ];
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  files = [
    {
      dest = ".config/helix/config.toml";
      src = ./config.toml;
    }
  ];
}
