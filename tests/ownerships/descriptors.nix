# a throwaway axis proving that one descriptor carries author syntax, scope,
# registry construction, and standalone roster projection end to end. production
# defaults remain host, user, and when; this descriptor exists only in this test.
{
  lib,
  krisis,
  axiom,
}:
let
  axes = import ../../src/ownerships/axes.nix { inherit lib krisis axiom; };
  engine = import ../../src/ownerships/engine.nix { inherit lib krisis axiom; };
  diagnosticAxes = import ../../src/ownerships/axes.nix {
    inherit lib axiom;
    krisis = krisis // {
      mkReporter = _options: {
        fail = diagnostics: diagnostics;
        failOne = diagnostic: [ diagnostic ];
      };
    };
  };

  roleDescriptor = axes.mkSetDescriptor {
    name = "role";
    includeKey = "roles";
    excludeKey = "exceptRoles";
    includeOrder = 60;
    excludeOrder = 70;
    allowedScopes = [ "user" ];
    roster = {
      membersField = "roles";
      define = name: {
        kind = "role";
        inherit name;
      };
      project =
        { declarations, ... }:
        {
          roles = lib.unique (
            map (declaration: declaration.name) (
              builtins.filter (declaration: declaration.kind == "role") declarations
            )
          );
        };
    };
  };

  descriptors = axes.descriptors ++ [ roleDescriptor ];
  hostRoleRelation = {
    name = "host-role-membership";
    leftAxis = "host";
    rightAxis = "role";
    unknownFor = _roster: {
      left = [ ];
      right = [ ];
    };
    compatibleFor =
      roster: host: role:
      builtins.elem role (roster.roleMembership.${host} or [ ]);
    reason =
      hosts: roles:
      "no role in { ${builtins.concatStringsSep ", " roles} } belongs to any host in { ${builtins.concatStringsSep ", " hosts} }";
  };
  relations = axes.relations ++ [ hostRoleRelation ];
  surface = import ../../src/ownerships/surface.nix {
    inherit
      lib
      krisis
      axiom
      descriptors
      relations
      ;
  };
  resolveLib = import ../../src/ownerships/resolve.nix {
    inherit
      lib
      krisis
      axiom
      descriptors
      relations
      ;
  };

  inherit (surface)
    define
    toRoster
    mkResolve
    mkResolveSystem
    translate
    ;

  roster = toRoster [
    (define.host "khion")
    (define.user "feltfomo" { hosts = [ "khion" ]; })
    (define.role "desktop")
    (define.role "laptop")
  ];

  relationRoster = roster // {
    roleMembership."standalone/khion" = [ "desktop" ];
  };
  resolve = mkResolve relationRoster;
  resolveSystem = mkResolveSystem relationRoster;
  ctx = {
    host.name = "khion";
    user.name = "feltfomo";
    role.name = "desktop";
  };
  ctxWithoutRole = removeAttrs ctx [ "role" ];

  throws = value: !(builtins.tryEval (builtins.deepSeq value value)).success;

  missingRoleUnit = {
    roles = [ "desktop" ];
    enabled = true;
  };
  translatedMissingRole = translate missingRoleUnit;
  inherit ((resolveLib.engineArgsFor roster)) registry;
  missingRoleLeaf = builtins.head (engine.compose registry translatedMissingRole);
  missingRoleClaim = missingRoleLeaf.claim.role;
  missingRoleReason = "axis 'role' is narrowed on by claim ${
    lib.generators.toPretty { multiline = false; } missingRoleClaim
  } but the build ctx provides no entity for key 'role' -- only untagged (global) claims resolve without a build context";
  renderedMissingRole = engine.renderDiags [
    {
      kind = "missing-ctx";
      unit = missingRoleLeaf.value;
      label = null;
      source = null;
      axis = "role";
      claims = missingRoleLeaf.claim;
      reason = missingRoleReason;
    }
  ];

  userDescriptor = builtins.head (
    builtins.filter (descriptor: descriptor.name == "user") axes.descriptors
  );

  tests = {
    "test set axis selection leaves a skipped roster member tail opaque" = {
      expr =
        let
          ownerships = import ../../src/ownerships {
            inherit
              lib
              krisis
              axiom
              descriptors
              ;
            relations = [ ];
          };
        in
        ownerships.mkResolve
          (
            roster
            // {
              roles = [
                "desktop"
                (throw "unused roster member tail")
              ];
            }
          )
          [
            {
              roles = [ "desktop" ];
              value.selected = true;
            }
          ]
          ctx == {
          selected = true;
        };
      expected = true;
    };
    "test suggestion helpers retain thresholds and the first tied candidate" = {
      expr =
        axes.editDistance "kitten" "sitting" == 3
        && axes.suggest [ "bat" "car" ] "cat" == "bat"
        && axes.suggest [ "far" ] "cat" == null
        && axes.suggest [ "sitting" ] "kitten" == "sitting"
        && axes.suggestionFor [ "bat" "car" ] "cat" == " -- did you mean 'bat'?"
        && axes.suggestionFor [ "far" ] "cat" == "";
      expected = true;
    };
    "test descriptor preparation transports opaque extension fields" = {
      expr =
        (axes.compileDescriptors [
          (roleDescriptor // { extensionPayload = throw "opaque descriptor extension payload"; })
        ]).claimKeys;
      expected = [
        "roles"
        "exceptRoles"
      ];
    };
    "test descriptor shape failures accumulate before duplicate registration" = {
      expr =
        let
          diagnostics = diagnosticAxes.validateDescriptors [
            (removeAttrs roleDescriptor [ "parse" ])
            (removeAttrs roleDescriptor [ "axisFor" ])
          ];
        in
        map (diagnostic: { inherit (diagnostic) code message; }) diagnostics == [
          {
            code = "ownerships/descriptor-malformed";
            message = "axis descriptor 'role' is missing required field 'parse'";
          }
          {
            code = "ownerships/descriptor-malformed";
            message = "axis descriptor 'role' is missing required field 'axisFor'";
          }
        ];
      expected = true;
    };
    "test descriptor collision diagnostics retain registry and authored order" = {
      expr = map (diagnostic: diagnostic.code) (
        diagnosticAxes.validateDescriptors [
          roleDescriptor
          roleDescriptor
        ]
      );
      expected = [
        "ownerships/descriptor-duplicate-name"
        "ownerships/descriptor-duplicate-key"
        "ownerships/descriptor-duplicate-key"
        "ownerships/descriptor-duplicate-order"
        "ownerships/descriptor-duplicate-order"
      ];
    };
    "test compiled descriptors retain ordered syntax and roster projections" = {
      expr =
        let
          compiled = axes.compileDescriptors descriptors;
        in
        map (descriptor: descriptor.name) compiled.descriptors == [
          "host"
          "user"
          "when"
          "role"
        ]
        && compiled.claimKeys == surface.claimKeys
        &&
          map (descriptor: descriptor.name) compiled.rosterDescriptors == [
            "host"
            "user"
            "role"
          ];
      expected = true;
    };
    "test relation stages follow satisfiability in registry order" = {
      expr = map (stage: stage.name or null) (resolveLib.engineArgsFor relationRoster).stages;
      expected = [
        null
        null
        "host-user-membership"
        "host-role-membership"
      ];
    };
    "test production descriptors remain host, user, and when" = {
      expr = map (descriptor: descriptor.name) axes.descriptors;
      expected = [
        "host"
        "user"
        "when"
      ];
    };
    "test one role descriptor adds include and exclude author keys" = {
      expr = surface.claimKeys;
      expected = [
        "hosts"
        "users"
        "exceptHosts"
        "exceptUsers"
        "when"
        "roles"
        "exceptRoles"
      ];
    };
    "test test-only host/role relation accepts a known compatible pair" = {
      expr = resolve [
        {
          hosts = [ "khion" ];
          roles = [ "desktop" ];
          enabled = true;
        }
      ] ctx;
      expected = {
        enabled = true;
      };
    };
    "test test-only host/role relation rejects a known incompatible pair" = {
      expr = resolve [
        {
          hosts = [ "khion" ];
          roles = [ "laptop" ];
          enabled = true;
        }
      ] ctx;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ enabled \\}: no role in \\{ laptop \\} belongs to any host in \\{ standalone/khion \\} \\(axes host, ro";
    };
    "test test-only host/role relation skips a global host side" = {
      expr = resolve [ missingRoleUnit ] ctx;
      expected = {
        enabled = true;
      };
    };
    "test role include selects its matching standalone context" = {
      expr = resolve [ missingRoleUnit ] ctx;
      expected = {
        enabled = true;
      };
    };
    "test role include drops a non-matching standalone context" = {
      expr = resolve [ missingRoleUnit ] (ctx // { role.name = "laptop"; });
      expected = { };
    };
    "test role exclude keeps a context outside the excluded set" = {
      expr = resolve [
        {
          exceptRoles = [ "laptop" ];
          enabled = true;
        }
      ] ctx;
      expected = {
        enabled = true;
      };
    };
    "test role exclude drops a context inside the excluded set" = {
      expr = resolve [
        {
          exceptRoles = [ "desktop" ];
          enabled = true;
        }
      ] ctx;
      expected = { };
    };
    "test role projection extends the standalone roster through define.role" = {
      expr =
        roster.roles == [
          "desktop"
          "laptop"
        ]
        &&
          builtins.attrNames roster == [
            "aliases"
            "dimensions"
            "display"
            "hosts"
            "membership"
            "roles"
            "users"
            "usersWithUnknownMembership"
          ];
      expected = true;
    };
    "test missing role context throws through the structured engine diagnostic path" = {
      expr =
        throws (resolve [ missingRoleUnit ] ctxWithoutRole)
        &&
          renderedMissingRole
          == "ownerships: 1 ownership error(s):\n  - unlabeled unit { enabled }: ${missingRoleReason} (axis 'role', claim ${
            lib.generators.toPretty { multiline = false; } missingRoleLeaf.claim
          })";
      expected = true;
    };
    "test system scope rejects a nested role claim through the generic recursive guard" = {
      expr = resolveSystem [
        {
          children = [
            {
              roles = [ "desktop" ];
              enabled = true;
            }
          ];
        }
      ] { host.name = "khion"; };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: a system-scope unit sets 'roles' = \\[\"desktop\"\\] -- this ownership axis is unavailable in system sco";
    };
    "test role system-scope message is pinned" = {
      expr = roleDescriptor.scopeError "system" "roles" [ "desktop" ];
      expected = "ownerships: a system-scope unit sets 'roles' = [\"desktop\"] -- this ownership axis is unavailable in system scope";
    };
    "test user system-scope message remains byte-identical" = {
      expr = userDescriptor.scopeError "system" "users" [ "feltfomo" ];
      expected = "ownerships: a system-scope (host-only) unit sets 'users' = [\"feltfomo\"] -- a host-only slice binds no user, so it cannot narrow on users. drop the user claim or resolve this unit at user scope.";
    };
    "test descriptor registration rejects malformed, duplicate-name, duplicate-key, and duplicate-order entries" =
      {
        expr =
          let
            duplicateKey = roleDescriptor // {
              name = "other";
            };
            duplicateOrder = roleDescriptor // {
              name = "other";
              authorKeys = [
                (
                  (builtins.elemAt roleDescriptor.authorKeys 0)
                  // {
                    name = "otherRoles";
                  }
                )
                (
                  (builtins.elemAt roleDescriptor.authorKeys 1)
                  // {
                    name = "otherExceptRoles";
                  }
                )
              ];
            };
          in
          throws (axes.validateDescriptors [ { } ])
          && throws (
            axes.validateDescriptors [
              roleDescriptor
              roleDescriptor
            ]
          )
          && throws (
            axes.validateDescriptors [
              roleDescriptor
              duplicateKey
            ]
          )
          && throws (
            axes.validateDescriptors [
              roleDescriptor
              duplicateOrder
            ]
          );
        expected = true;
      };
    "test relation registration rejects a relation without a reason" = {
      expr = axes.validateRelations descriptors [ (removeAttrs hostRoleRelation [ "reason" ]) ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/relation-malformed\\] relation 'host-role-membership' is missing required field 'reason'";
    };
    "test relation registration rejects a duplicate relation name" = {
      expr = axes.validateRelations descriptors [
        hostRoleRelation
        (hostRoleRelation // { rightAxis = "user"; })
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/relation-duplicate-name\\] duplicate relation name 'host-role-membership'";
    };
    "test relation registration rejects an unknown axis" = {
      expr = axes.validateRelations descriptors [
        (hostRoleRelation // { rightAxis = "missing"; })
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/relation-unknown-axis\\] relation 'host-role-membership' references unknown axis 'missing' as rightA";
    };
  };

in
{
  inherit tests;
}
