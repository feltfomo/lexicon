{
  pkgs,
  root,
  ...
}:
{
  atRoot = true;
  commands = {
    inspect = {
      description = "Evaluate the project status";
      command = [
        "nix"
        "eval"
        "--json"
        ".#status"
      ];
    };
    arguments = {
      description = "Show forwarded argument boundaries";
      # jq makes empty and space-containing arguments visible
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
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
    summary = {
      description = "Label the evaluated status";
      shell = "printf 'status='; nix eval --json .#status";
    };
    list = {
      description = "A command whose name matches a built-in";
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s\n"
        "declared list command"
      ];
    };
  };
  tasks.verify = {
    description = "Inspect the project and then run its checks";
    steps = [
      "inspect"
      "check"
    ];
  };
}
