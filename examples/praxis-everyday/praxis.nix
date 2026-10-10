{
  pkgs,
  root,
  ...
}:
{
  atRoot = true;
  commands = {
    hosts = {
      description = "List the hosts this configuration builds";
      command = [
        "nix"
        "eval"
        "--json"
        ".#hosts"
      ];
    };
    target = {
      description = "Show the host name a rebuild would use";
      positional = [ "host" ];
      parameters = {
        host = {
          description = "Which host to act on";

          choices = [
            "workstation"
            "server"
          ];
        };
      };
      # an argv command inserts the bound value here instead of reading an environment name
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s\n"
        { param = "host"; }
      ];
      forwardArgs = false;
    };
    rebuild = {
      description = "Switch one host to the current configuration";
      # this command changes the running system, so it asks before acting
      confirm = "Switch this machine to the current configuration?";
      positional = [ "host" ];
      parameters = {
        host = {
          # praxis rebuild server binds "server" here, because the parameter is positional

          description = "Which host to switch";

          # an unlisted name is refused during binding, before sudo runs
          choices = [
            "workstation"
            "server"
          ];
        };
      };
      # the declared name reaches a shell action as PRAXIS_ARG_HOST, so this line
      # becomes sudo nixos-rebuild switch --flake ".#server"
      shell = ''sudo nixos-rebuild switch --flake ".#$PRAXIS_ARG_HOST"'';
      forwardArgs = false;
    };
    update = {
      description = "Update the flake inputs";
      command = [
        "nix"
        "flake"
        "update"
      ];
    };
    check = {
      description = "Run the project checks";
      command = [
        "nix"
        "flake"
        "check"
        "-L"
      ];
    };
  };
}
