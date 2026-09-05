{ pkgs }:
{
  description = "Run project tests";
  runtimeInputs = [ pkgs.bash ];
  steps = [
    {
      script = "scripts/test.sh";
      interpreter = "bash";
      forwardArgs = true;
    }
  ];
}
