{ lib }:
let
  fromRoster = roster: {
    host = {
      choices = lib.sort builtins.lessThan roster.hosts;
    };
    user = {
      choices = lib.sort builtins.lessThan roster.users;
    };
  };
in
{
  inherit fromRoster;
  # the den adapter owns roster extraction, not the command runtime
  fromDen = adapter: fromRoster adapter.roster;
}
