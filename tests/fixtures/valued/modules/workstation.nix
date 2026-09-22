# one user, so the entity the interior reads carries something past its name
{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    users = {
      ada = { };
    };
  };
}
