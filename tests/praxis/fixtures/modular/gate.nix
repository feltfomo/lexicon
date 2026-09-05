{
  description = "Format and test the project";
  steps = [
    { command = "fmt"; }
    { command = "test"; }
  ];
}
