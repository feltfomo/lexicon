{ lexicon }:
let
  ownerships = lexicon.lib.ownerships { };
  roster = import ./roster.nix { inherit ownerships; };
  editorFor = user: command: {
    label = "${user}'s editor";
    users = [ user ];
    editor.command = command;
  };
  # importUnits binds the shared helper and keeps numbered file order
  units = ownerships.importUnits {
    dir = ./units;
    args = { inherit editorFor; };
  };
  context = name: user: {
    host = {
      inherit name;
      id = "x86_64-linux/${name}";
      mobile = name == "laptop";
    };
    user.name = user;
  };
  resolvers = ownerships.mkResolvers roster;
  # prepare the shared unit set once for every modeled context
  resolve = resolvers.prepared units;
in
{
  inherit roster units context;
  alice = resolve (context "workstation" "alice");
  sam = resolve (context "workstation" "sam");
  laptop = resolve (context "laptop" "alice");
  robin = resolve (context "laptop" "robin");
  # matrix callbacks receive canonical host ids rather than short claim aliases
  matrix = resolvers.matrix {
    inherit units;
    contextFor = { hostName, userName }: {
      host = {
        id = hostName;
        mobile = hostName == "x86_64-linux/laptop";
      };
      user.name = userName;
    };
  };
}
