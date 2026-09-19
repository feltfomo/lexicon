{ lexicon, pkgs }:
let
  inherit (pkgs) lib;
  registry = lexicon.lib.registry (import ./lexicon.nix);
  inherit (registry) roster;
  context = registry.context { host = "workstation"; };
  inherit (context) host;
  program = lexicon.lib.programOwnerships {
    inherit lib roster;
  };
  editor = program (import ./editor.nix);
  choices = (lexicon.lib.praxisAdapters { inherit lib; }).fromRoster roster;
  tasks = lexicon.lib.praxis {
    inherit pkgs;
    inherit (registry) root;
    atRoot = true;
    devShell = true;
    # availability uses the build context, not a runtime --host choice
    ownership = {
      inherit roster context;
      scope = "system";
    };
    commands.target = {
      hosts = [ "workstation" ];
      description = "Print a known host identifier";
      parameters = [
        (
          choices.host
          // {
            required = true;
            short = "H";
          }
        )
      ];
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s\n"
        { param = "host"; }
      ];
      label = "Selected host";
      forwardArgs = false;
    };
  };
in
{
  inherit
    registry
    roster
    host
    editor
    tasks
    ;
  forUser =
    name:
    let
      user = { inherit name; };
    in
    {
      nixos =
        { config, pkgs, ... }:
        editor.nixos {
          inherit
            config
            pkgs
            host
            user
            ;
        };
      homeManager =
        { lib, pkgs, ... }:
        editor.homeManager {
          inherit
            lib
            pkgs
            host
            user
            ;
        };
    };
}
