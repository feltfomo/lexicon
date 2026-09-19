{ pkgs }:
{
  inherit pkgs;
  root = ./.;
  atRoot = true;
  commands = {
    tool = [
      "printf"
      "literal"
    ];
    script = {
      script = ./ci/fail.sh;
      interpreter = "${pkgs.bash}/bin/bash";
    };
  };
  tasks.gate = [
    "tool"
    "script"
  ];
}
