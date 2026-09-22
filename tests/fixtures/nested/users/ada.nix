# one file, one user, and nothing in it names a host
{ user, ... }:
user {
  declare = {
    shell = "/bin/fish";
  };
}
