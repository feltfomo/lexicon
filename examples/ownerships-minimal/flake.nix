{
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { lexicon, ... }:
    let
      ownerships = lexicon.lib.ownerships { };
      # the roster bounds which host and user names can be resolved
      roster = ownerships.toRoster [
        (ownerships.define.host "laptop")
        (ownerships.define.user "alice" { hosts = [ "laptop" ]; })
      ];
      units = [
        {
          users = [ "alice" ];
          editor = "helix";
        }
      ];
    in
    {
      # resolution needs both host and user context even for one matching unit
      lib.result = ownerships.mkResolve roster units {
        host.name = "laptop";
        user.name = "alice";
      };
    };
}
