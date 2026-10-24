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
    finishComputation
    nonempty
    ;
  inherit (krisis.effects)
    native
    accept
    fromAxiom
    resultOf
    ;
  inherit (native) validation;
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
  validateComputation =
    target:
    validation.andThen (
      checked:
      validation.andThen
        (
          values:
          let
            host = builtins.elemAt values 0;
            user = builtins.elemAt values 1;
          in
          accept {
            host = host // {
              id = host.id or "${host.system}/${host.name}";
            };
            user = if user == null then null else user // { home = user.home or "/home/${user.name}"; };
          }
        )
        (
          validation.all [
            (fromAxiom (hostSchema checked.host))
            (if (checked.user or null) == null then accept null else fromAxiom (userSchema checked.user))
          ]
        )
    ) (fromAxiom (targetSchema target));
  validate = target: resultOf (validateComputation target);
  normalize =
    target:
    let
      result = finishComputation (validateComputation target);
    in
    builtins.deepSeq result result;
in
{
  inherit validate validateComputation normalize;
}
