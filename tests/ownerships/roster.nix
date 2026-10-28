# unknown membership and known-empty membership have different selection semantics
{
  lib,
  krisis,
  axiom,
}:
let
  axes = import ../../src/ownerships/axes.nix { inherit lib krisis axiom; };
  resolve = import ../../src/ownerships/resolve.nix { inherit lib krisis axiom; };

  inherit (axes) include;
  inherit (resolve) define toRoster resolveWith;

  roster = toRoster [
    (define.host "khion")
    (define.host "lumi")
    (define.host "server")
    (define.user "feltfomo" {
      hosts = [
        "khion"
        "lumi"
      ];
    })
    (define.user "grandpa" { hosts = [ "lumi" ]; })
    (define.user "nomad" { })
    (define.user "ghostless" { hosts = [ ]; })
  ];

  ctxOf = h: u: {
    host.name = h;
    user.name = u;
  };

  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;

  r = ctx: unit: resolveWith { inherit roster ctx; } unit;

  ownerships = import ../../src/ownerships { inherit lib krisis axiom; };
  strict =
    scope:
    ownerships.resolverFor {
      inherit roster scope;
      projection = "value";
      strict = true;
    };

  rawNarrowing = [
    {
      name = "include meet compares aliases and canonical names before observation";
      parent.hosts = [
        "khion"
        "lumi"
        "khion"
      ];
      child.hosts = [
        "standalone/khion"
        "lumi"
      ];
      claim = axes.include [ "lumi" ];
      members = [ "standalone/lumi" ];
      selected = false;
    }
    {
      name = "canonical exclusion does not erase a raw alias include";
      parent.hosts = [
        "khion"
        "lumi"
        "khion"
      ];
      child.exceptHosts = [ "standalone/khion" ];
      claim = axes.include [
        "khion"
        "lumi"
        "khion"
      ];
      members = [
        "standalone/khion"
        "standalone/lumi"
      ];
      selected = true;
    }
    {
      name = "parent canonical exclusion retains child alias duplicates and order";
      parent.exceptHosts = [ "standalone/khion" ];
      child.hosts = [
        "khion"
        "khion"
        "lumi"
      ];
      claim = axes.include [
        "khion"
        "khion"
        "lumi"
      ];
      members = [
        "standalone/khion"
        "standalone/lumi"
      ];
      selected = true;
    }
    {
      name = "exclude meet retains authored duplicates before alias observation";
      parent.exceptHosts = [
        "khion"
        "khion"
      ];
      child.exceptHosts = [
        "khion"
        "standalone/khion"
        "standalone/khion"
      ];
      claim = axes.exclude [
        "khion"
        "khion"
        "standalone/khion"
        "standalone/khion"
      ];
      members = [
        "standalone/lumi"
        "standalone/server"
      ];
      selected = false;
    }
  ];

  # one trace per row so a mismatch names the narrowing step that broke
  narrowingTests = lib.listToAttrs (
    map (
      expected:
      let
        observed = ownerships.mkResolveSystemTrace roster [
          (
            expected.parent
            // {
              children = [ (expected.child // { value.selected = true; }) ];
            }
          )
        ] { host.name = "khion"; };
        leaf = builtins.head observed.trace;
      in
      lib.nameValuePair "test ${expected.name}" {
        expr = {
          claim = leaf.effectiveClaim.host;
          claimFields = builtins.attrNames leaf.effectiveClaim.host;
          members = leaf.axisResults.host.details.materializedMembers;
          inherit (leaf) selected;
          inherit (observed) value;
        };
        expected = {
          inherit (expected) claim members selected;
          claimFields = [
            "set"
            "tag"
          ];
          value = if expected.selected then { selected = true; } else { };
        };
      }
    ) rawNarrowing
  );

  tests = narrowingTests // {
    "test canonical membership takes precedence over a colliding alias" = {
      expr =
        ownerships.mkResolveSystem
          (
            roster
            // {
              aliases = roster.aliases // {
                host = roster.aliases.host // {
                  "standalone/khion" = [ "standalone/lumi" ];
                };
              };
            }
          )
          [
            {
              hosts = [ "standalone/khion" ];
              value.selected = true;
            }
          ]
          { host.name = "khion"; };
      expected = {
        selected = true;
      };
    };
    "test strict system resolution accepts a canonical host id without a display name" = {
      expr = strict "system" [ { value.x = 1; } ] { host.id = "standalone/khion"; };
      expected = {
        x = 1;
      };
    };
    "test strict user resolution accepts canonical ids with real membership" = {
      expr = strict "user" [ { value.x = 1; } ] {
        host.id = "standalone/khion";
        user.id = "feltfomo";
      };
      expected = {
        x = 1;
      };
    };
    "test canonical ids can label context diagnostics without display names" = {
      expr = axes.ctxLabelFor axes.descriptors {
        host.id = "standalone/khion";
        user.id = "feltfomo";
      };
      expected = "host 'standalone/khion', user 'feltfomo'";
    };
    "test define.* resolves a nested host+user unit with no den" = {
      expr = r (ctxOf "khion" "feltfomo") {
        claim.host = include [
          "khion"
          "lumi"
        ];
        children = [
          { value.packages = [ "a" ]; }
          {
            claim.user = include [ "feltfomo" ];
            value.packages = [ "b" ];
          }
        ];
      };
      expected = {
        packages = [
          "a"
          "b"
        ];
      };
    };
    "test cross-axis membership fires: grandpa is not on khion" = {
      expr = r (ctxOf "khion" "grandpa") {
        claim.host = include [ "khion" ];
        children = [
          {
            claim.user = include [ "grandpa" ];
            value.x = 1;
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ x \\}: no user in \\{ grandpa \\} lives on any host in \\{ standalone/khion \\} -- this host/user co-";
    };
    "test unknown-membership user degrades to same-axis-only" = {
      expr = r (ctxOf "khion" "nomad") {
        claim.host = include [ "khion" ];
        children = [
          {
            claim.user = include [ "nomad" ];
            value.x = 1;
          }
        ];
      };
      expected = {
        x = 1;
      };
    };
    "test known-none user still trips membership (null vs [])" = {
      expr = r (ctxOf "khion" "ghostless") {
        claim.host = include [ "khion" ];
        children = [
          {
            claim.user = include [ "ghostless" ];
            value.x = 1;
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ x \\}: no user in \\{ ghostless \\} lives on any host in \\{ standalone/khion \\} -- this host/user c";
    };
    "test host-only config on a user-less host is not a membership error" = {
      expr = r (ctxOf "server" "feltfomo") {
        claim.host = include [ "server" ];
        value.systemPackages = [ "vim" ];
      };
      expected = {
        systemPackages = [ "vim" ];
      };
    };
    "test distinct canonical user ids select without conflating a shared bare name" = {
      expr =
        let
          federated = toRoster [
            (define.host "khion")
            (define.host "lumi")
            (define.user "operator" {
              id = "khion/operator";
              hosts = [ "khion" ];
            })
            (define.user "operator" {
              id = "lumi/operator";
              hosts = [ "lumi" ];
            })
          ];
          selected =
            resolveWith
              {
                roster = federated;
                ctx = {
                  host.name = "khion";
                  user = {
                    name = "operator";
                    id = "khion/operator";
                  };
                };
              }
              {
                claim.user = include [ "khion/operator" ];
                value.x = 1;
              };
          ambiguous =
            resolveWith
              {
                roster = federated;
                ctx = {
                  host.name = "khion";
                  user = {
                    name = "operator";
                    id = "khion/operator";
                  };
                };
              }
              {
                claim.user = include [ "operator" ];
                value.x = 1;
              };
        in
        selected == { x = 1; } && throws ambiguous;
      expected = true;
    };
    "test grouped host aliases retain declaration order" = {
      expr =
        let
          federated = toRoster [
            (define.host "khion" { system = "x86_64-linux"; })
            (define.host "khion" { system = "aarch64-linux"; })
          ];
        in
        federated.aliases.host.khion == [
          "x86_64-linux/khion"
          "aarch64-linux/khion"
        ];
      expected = true;
    };
    "test an unknown user host reference fails during roster construction" = {
      expr = toRoster [
        (define.host "khion")
        (define.user "operator" { hosts = [ "ghost" ]; })
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/roster-unknown-host\\] user roster references unknown host 'ghost'";
    };
    "test an ambiguous user host reference fails during roster construction" = {
      expr = toRoster [
        (define.host "khion" { system = "x86_64-linux"; })
        (define.host "khion" { system = "aarch64-linux"; })
        (define.user "operator" { hosts = [ "khion" ]; })
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/roster-ambiguous-host\\] user roster host alias 'khion' is ambiguous; use a canonical system/name";
    };
  };

in
{
  inherit tests;
}
