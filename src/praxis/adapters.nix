{ lib }:
let
  fromRoster = roster: {
    host = {
      name = "host";
      choices = lib.sort builtins.lessThan roster.hosts;
    };
    user = {
      name = "user";
      choices = lib.sort builtins.lessThan roster.users;
    };
  };
in
{
  inherit fromRoster;
  # the den adapter owns roster extraction, not the command runtime
  fromDen = adapter: fromRoster adapter.roster;
}
