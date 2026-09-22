# reads an evaluated den configuration, the attrset carrying hosts. den keeps
# hosts in module configuration and exposes none of them at a flake output
# boundary, so a flake is never what this reads. every key set named in this
# file was read from den at 90c303be407632d3983fb619e714c53b2349b8e6
{ lib }:
let
  # applied by name before any value is read. a den user carries its whole
  # host, and a builder field costs a system evaluation to look at
  dropped = [
    "instantiate"
    "intoAttr"
    "mainModule"
    "aspect"
    "aspects"
    "hasAspect"
    "resolved"
    "__resolveResult"
    "__pathSetByScope"
    "__scopeName"
    "_identity"
    "_identityKeys"
    "collisionPolicy"
    "host"
  ];

  # users is consumed to produce user entities, so it travels as structure
  # and never as an inherited field
  consumed = [ "users" ];

  # den's host submodule is freeform, so what the drop list leaves behind
  # travels whole
  carried = attrs: builtins.removeAttrs attrs (dropped ++ consumed);

  usersOf = attrs: if builtins.isAttrs (attrs.users or null) then attrs.users else { };

  userOf = system: hostName: name: attrs: {
    kind = "user";
    inherit name;
    parent = hostName;
    path = [
      system
      hostName
      "users"
      name
    ];
    fields = { };
    inherited = carried attrs;
    evidence = null;
  };

  # den's class vocabulary is its own and stays under inherited
  hostOf = system: name: attrs: {
    kind = "host";
    inherit name;
    parent = null;
    path = [
      system
      name
    ];
    fields = {
      system = attrs.system or system;
    };
    inherited = carried attrs;
    evidence = attrs.description or null;
  };

  entitiesOf =
    system: held: name:
    let
      host = held.${name};
    in
    [ (hostOf system name host) ]
    ++ lib.mapAttrsToList (userName: user: userOf system name userName user) (usersOf host);

  # a flake is the argument to expect by mistake
  flakeLike = value: value ? outputs || value ? denful || value ? sourceInfo;

  usable = value: builtins.isAttrs value && builtins.isAttrs (value.hosts or null);

  read =
    configuration:
    if usable configuration then
      {
        name = "den";
        kind = "host";
        ok = true;
        entities = lib.concatMap (
          system:
          lib.concatMap (entitiesOf system configuration.hosts.${system}) (
            builtins.attrNames configuration.hosts.${system}
          )
        ) (builtins.attrNames configuration.hosts);
      }
    else
      let
        flake = builtins.isAttrs configuration && flakeLike configuration;
      in
      {
        name = "den";
        kind = "host";
        ok = false;
        entities = [ ];
        inherit flake;
        wanted = "an evaluated den configuration, the attrset carrying hosts";
        got = if flake then "a flake" else builtins.typeOf configuration;
      };
in
{
  inherit read dropped;
}
