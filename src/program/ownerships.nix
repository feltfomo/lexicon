{
  lib,
  krisis,
  axiom,
  mkCoordinator,
  roster ? null,
}:
let
  programReport = import ./report.nix { inherit lib krisis axiom; };
  inherit (programReport) problem;
  inherit (programReport.reporter) checked;

  stringList = value: builtins.isList value && builtins.all builtins.isString value;
  membership = value: builtins.isAttrs value && builtins.all stringList (builtins.attrValues value);
  invalid =
    code: subject: message:
    problem {
      inherit code message;
      primary.label = subject;
    };

  rosterErrors =
    if !builtins.isAttrs roster then
      [
        (invalid "ownerships-roster-shape" "roster"
          "programOwnerships requires the attribute set returned by ownerships.toRoster"
        )
      ]
    else
      lib.optional (!stringList (roster.hosts or null)) (
        invalid "ownerships-roster-hosts" "roster.hosts" "roster.hosts must be a list of names"
      )
      ++ lib.optional (!stringList (roster.users or null)) (
        invalid "ownerships-roster-users" "roster.users" "roster.users must be a list of names"
      )
      ++ lib.optional (!membership (roster.membership or null)) (
        invalid "ownerships-roster-membership" "roster.membership"
          "roster.membership must map host identities to lists of users"
      )
      ++ lib.optional (!stringList (roster.usersWithUnknownMembership or null)) (
        invalid "ownerships-roster-unknown-membership" "roster.usersWithUnknownMembership"
          "roster.usersWithUnknownMembership must be a list of users"
      );

  checkedRoster = checked rosterErrors roster;
  principalFor =
    user:
    let
      identity = user.id or user.name;
    in
    {
      authority = {
        scope = "user";
        inherit identity;
      };
      managedRoot = user.home or "/home/${identity}";
    };

  filePrincipals =
    {
      user ? null,
      ...
    }:
    lib.optional (user != null) (principalFor user);

  hostUserNames =
    { system, host }:
    checkedRoster.membership."${system}/${host}" or (checkedRoster.membership.${host} or [ ]);
in
builtins.seq checkedRoster (
  import ./bind-ownerships.nix {
    inherit
      lib
      krisis
      axiom
      mkCoordinator
      filePrincipals
      hostUserNames
      ;
    roster = checkedRoster;
  }
)
