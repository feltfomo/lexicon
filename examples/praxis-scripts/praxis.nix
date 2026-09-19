{
  pkgs,
  root,
  ...
}:
{
  # the installed command supplies the project source root

  atRoot = true;
  commands = {
    source-script = {
      description = "Run a source-backed script from another working directory";
      script = root + "/scripts/source.sh";
      interpreter = "${pkgs.bash}/bin/bash";
      cwd = "work";
    };
    generated-script = {
      description = "Run a script created earlier in the workflow";
      script = "generated/run.sh";
      interpreter = "${pkgs.bash}/bin/bash";
    };
    source-check = {
      description = "Check the source-backed script in a flake check";
      script = root + "/scripts/source.sh";
      interpreter = "${pkgs.bash}/bin/bash";
    };
  };
  tasks.generate = {
    description = "Create and then run a live relative script";
    steps = [
      {
        shell = ''
          ${pkgs.coreutils}/bin/mkdir -p generated
          printf '%s\n' "printf 'generated script\n'" > generated/run.sh
        '';
      }
      "generated-script"
    ];
  };
  # publish-time only: read when this declaration is compiled by
  # lexicon.lib.praxis, ignored by the installed command
  checks = [ "source-check" ];
}
