{ user, ... }:
user {
  declare = {
    shell = "/run/current-system/sw/bin/fish";
    elevated = true;
  };
}
