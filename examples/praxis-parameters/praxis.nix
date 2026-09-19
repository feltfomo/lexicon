{
  pkgs,
  root,
  ...
}:
{
  commands = {
    greet = {
      description = "Greet one person";
      parameters = [
        {
          name = "name";
          positional = true;
          required = true;
        }
        {
          name = "greeting";
          short = "g";
          choices = [
            "hello"
            "welcome"
          ];
          default = "hello";
        }
      ];
      # parameter references preserve argv boundaries without shell interpolation
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s, %s!\n"
        { param = "greeting"; }
        { param = "name"; }
      ];
      forwardArgs = false;
    };
    inspect = {
      description = "Show typed parameter values";
      parameters = [
        {
          name = "count";
          type = "int";
          short = "n";
          default = 1;
        }
        {
          name = "loud";
          type = "bool";
        }
        {
          name = "destination";
          type = "path";
          env = "PRAXIS_DESTINATION";
          default = "report.txt";
        }
      ];
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
        { param = "count"; }
        { param = "loud"; }
        { param = "destination"; }
      ];
      forwardArgs = false;
    };
    forward = {
      description = "Forward remaining argv without re-parsing it";
      # no forwardArgs = false here, so remaining argv reaches the command unparsed
      parameters = [
        {
          name = "tag";
          default = "outer";
        }
      ];
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
      ];
    };
  };
}
