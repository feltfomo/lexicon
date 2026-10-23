{
  source,
  component,
  size,
  bad ? false,
  artifact ? false,
}:
let
  project = builtins.getFlake source;
  inherit (project.inputs.nixpkgs) lib;
  pkgs = project.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  api = project.lib;
  names = builtins.genList (i: "item${toString i}") size;
  records =
    f:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = f name;
      }) names
    );
  ownerships = api.ownerships { };
  roster = ownerships.toRoster [
    (ownerships.define.host "host" { system = "x86_64-linux"; })
    (ownerships.define.user "user" { hosts = [ "host" ]; })
  ];
  target = {
    host.name = "host";
    host.system = "x86_64-linux";
    user.name = "user";
  };
  declaration = api.lexicon.forTarget { inherit target; } {
    homeManager = {
      environment = records (_: true);
    };
  };
  resources = api.lexicon.forTarget { inherit target; } {
    furnish.links = map (name: {
      source = if bad then 1 else "/external/${name}";
      destination = ".links/${name}";
    }) names;
  };
  resourceModule = resources.nixos {
    inherit lib pkgs;
    config.lexicon.furnish.declarations = [ ];
  };
  resourceEntries =
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon) resourceModule.imports
    )).lexicon.furnish.declarations;
  praxis = api.praxis {
    inherit pkgs;
    commands = records (_: if bad then 42 else [ "true" ]);
  };
  workloads = {
    ownerships = ownerships.mkResolve roster (map (name: {
      users = [ (if bad then "unknown" else "user") ];
      values.${name} = true;
    }) names) target;
    registry =
      (api.registry {
        root = ./.;
        runtimeRoot = null;
        defaultSystem = "x86_64-linux";
        hosts = records (_: if bad then { unknown = true; } else { });
        users = { };
      }).summary;
    declaration =
      if bad then
        builtins.attrNames (
          api.lexicon.forTarget { inherit target; } {
            unknown = true;
          }
        )
      else
        (declaration.homeManager { inherit lib pkgs; }).imports;
    resource = map (entry: entry.destination) resourceEntries;
    toml = (api.toml { inherit pkgs; }).generate "component" (records (_: if bad then x: x else 1));
    praxis = praxis.manifest;
  };
in
assert size > 0;
if artifact then
  workloads.toml
else
  {
    inherit component size;
    value = if component == "toml" then toString workloads.toml else workloads.${component};
  }
