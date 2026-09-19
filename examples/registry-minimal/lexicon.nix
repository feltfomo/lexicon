{
  root = ./.;
  runtimeRoot = "/etc/paperkite";
  defaultSystem = "x86_64-linux";

  dimensions.role = {
    values = [
      "desktop"
      "server"
    ];
    required = true;
  };

  hosts.workstation = {
    aliases = [
      "workstation"
      "desk"
    ];
    dimensions.role = "desktop";
    users.river = {
      aliases = [
        "river"
        "operator"
      ];
    };
  };

  users = { };
}
