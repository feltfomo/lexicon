{
  description = "Format the project";
  steps = [
    {
      exec = [
        "nix"
        "fmt"
      ];
    }
  ];
}
