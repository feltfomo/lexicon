# the host declares a field no kind in this tree holds. it is a field only
# because the caller contributed one
{ host, ... }:
host {
  declare = {
    system = "x86_64-linux";
    users = { };
    badge = "gold";
  };
}
