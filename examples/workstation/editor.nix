{
  users = [ "alice" ];
  pkg = pkgs: pkgs.helix;
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  files = [
    {
      dest = ".config/helix/config.toml";
      src = ./helix.toml;
      onConflict = "error";
      provenance = "editor.nix";
    }
  ];
}
