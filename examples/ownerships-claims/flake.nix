{
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { lexicon, ... }:
    let
      ownerships = lexicon.lib.ownerships { };
      roster = ownerships.toRoster [
        (ownerships.define.host "workstation")
        (ownerships.define.host "laptop")
        (ownerships.define.user "alice" {
          hosts = [
            "workstation"
            "laptop"
          ];
        })
        (ownerships.define.user "sam" { hosts = [ "workstation" ]; })
      ];
      units = import ./units.nix;
      resolve = ownerships.mkResolve roster units;
      # predicate units read mobile from context rather than roster metadata
      context = name: user: {
        host = {
          inherit name;
          mobile = name == "laptop";
        };
        user.name = user;
      };
    in
    {
      lib = {
        inherit roster units context;
        alice = resolve (context "workstation" "alice");
        sam = resolve (context "workstation" "sam");
        laptop = resolve (context "laptop" "alice");
      };
    };
}
