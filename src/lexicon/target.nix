{
  lib,
  axiom,
  krisis,
}:
let
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  inherit (report)
    field
    schema
    finish
    nonempty
    ;
  inherit (axiom) validation;
  hostPath = [
    "target"
    "host"
  ];
  userPath = [
    "target"
    "user"
  ];
  hostSchema = schema hostPath {
    name = field hostPath "name" nonempty;
    system = field hostPath "system" nonempty;
    id = (field hostPath "id" nonempty) // {
      required = false;
    };
  };
  userSchema = schema userPath {
    name = field userPath "name" nonempty;
    home = (field userPath "home" (v: nonempty v && lib.hasPrefix "/" v)) // {
      required = false;
    };
  };
  targetSchema = schema [ "target" ] {
    host = field [ "target" ] "host" builtins.isAttrs;
    user = {
      validate = v: v == null || builtins.isAttrs v;
      onInvalid = _: _: report.at userPath "target-user" "user must be a record or null";
    };
  };
  validate =
    target:
    validation.andThen (
      checked:
      validation.map2
        (host: user: {
          host = host // {
            id = host.id or "${host.system}/${host.name}";
          };
          user = if user == null then null else user // { home = user.home or "/home/${user.name}"; };
        })
        (hostSchema checked.host)
        (if (checked.user or null) == null then validation.success null else userSchema checked.user)
    ) (targetSchema target);
  normalize =
    target:
    let
      result = finish (validate target);
    in
    builtins.deepSeq result result;
in
{
  inherit validate normalize;
}
