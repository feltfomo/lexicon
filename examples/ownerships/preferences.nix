{ lexicon, lib }:
let
  ownerships = lexicon.lib.ownerships { inherit lib; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { system = "x86_64-linux"; })
    (ownerships.define.host "laptop" { system = "x86_64-linux"; })
    (ownerships.define.user "alice" {
      hosts = [
        "workstation"
        "laptop"
      ];
    })
    (ownerships.define.user "sam" { hosts = [ "workstation" ]; })
  ];
  # one resolver set keeps values and inspection on the same roster
  resolvers = ownerships.mkResolvers roster;
  units = [
    {
      label = "common tools";
      value.tools = [ "git" ];
    }
    {
      label = "alice's editor";
      users = [ "alice" ];
      value.tools = [ "helix" ];
    }
    {
      label = "battery settings";
      hosts = [ "laptop" ];
      value.lowPower = true;
    }
  ];
  # canonical host ids keep system and machine identity together
  context = host: user: {
    host.id = "x86_64-linux/${host}";
    user.name = user;
  };
  resolve = ownerships.mkResolve roster units;
  trace = resolvers.trace units (context "workstation" "alice");
in
{
  inherit roster units trace;
  alice = resolve (context "workstation" "alice");
  sam = resolve (context "workstation" "sam");
  laptop = resolve (context "laptop" "alice");
  inspection = map (entry: {
    inherit (entry) identity selected rejectedBy;
  }) trace.trace;
  matrix = resolvers.matrix { inherit units; };
}
