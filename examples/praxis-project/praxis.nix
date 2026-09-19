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
    build = {
      description = "Build the supplied harmless output";
      command = [
        "nix"
        "build"
        ".#default"
      ];
    };
    check = {
      description = "Run every project check";
      command = [
        "nix"
        "flake"
        "check"
        "-L"
      ];
    };
  };
  tasks.verify = {
    description = "Inspect and check the project";
    # composition comes after each direct command remains useful alone
    steps = [
      "inspect"
      "check"
    ];
  };
}
