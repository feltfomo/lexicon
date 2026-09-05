{
  description = "Build a selected flake output";
  parameters = [
    {
      name = "target";
      positional = true;
      default = ".#default";
    }
  ];
  steps = [
    {
      exec = [
        "nix"
        "build"
        { param = "target"; }
      ];
      forwardArgs = true;
    }
  ];
}
