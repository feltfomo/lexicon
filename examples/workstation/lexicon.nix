{
  root = ./.;
  runtimeRoot = null;
  defaultSystem = "x86_64-linux";

  hosts.workstation = {
    dimensions.role = "workstation";
    users.alice = { };
  };

  users = { };
}
