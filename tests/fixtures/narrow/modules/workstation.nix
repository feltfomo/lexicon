{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    users = {
      ada = { };
    };
  };
}
