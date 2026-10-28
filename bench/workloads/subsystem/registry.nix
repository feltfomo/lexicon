# the registry summary over size hosts, then size users with size memberships
# each answering usersOn, forSystem, hostsFor and homeFor per name
{
  api,
  names,
  records,
  ...
}:
let
  hosts = api.registry {
    root = ./.;
    runtimeRoot = null;
    defaultSystem = "x86_64-linux";
    hosts = records (_: { });
    users = { };
  };

  fleet = api.registry {
    root = ./.;
    runtimeRoot = null;
    defaultSystem = "fleet";
    hosts = records (_: { });
    users = records (_: {
      hosts = names;
    });
  };
in
{
  inherit (hosts) summary;

  queries = map (name: {
    users = map (user: user.name) (fleet.usersOn name);
    systems = map (host: host.name) (fleet.forSystem "fleet");
    hosts = map (host: host.name) (fleet.hostsFor name);
    home = fleet.homeFor {
      host = name;
      user = name;
    };
  }) names;
}
