# proof for the authoring surface, with throwaway aspects written the way a real
# one would be and resolved against a small fleet. `results` stays plain so it
# can be eyeballed with `nix eval`. nothing den-related is imported, so a green
# run also proves the surface resolves standalone.
{
  lib,
  krisis,
  axiom,
}:
let
  axes = import ../../src/ownerships/axes.nix { inherit lib krisis axiom; };
  resolveLib = import ../../src/ownerships/resolve.nix { inherit lib krisis axiom; };
  surface = import ../../src/ownerships/surface.nix { inherit lib krisis axiom; };
  inherit (surface)
    define
    toRoster
    mkResolve
    mkResolveSystem
    mkResolveTrace
    mkResolveSystemTrace
    mkResolveStrict
    mkResolveSystemStrict
    mkResolveProfiled
    mkResolveSystemProfiled
    translate
    claimKeys
    ;

  roster = toRoster [
    (define.host "khion")
    (define.host "lumi")
    (define.user "feltfomo" {
      hosts = [
        "khion"
        "lumi"
      ];
    })
    (define.user "grandpa" { hosts = [ "lumi" ]; })
    # hosts = null (the default) - unknown host membership, rescued through
    # the membership check the same way strict validation must rescue it.
    (define.user "nomad" { })
  ];

  resolve = mkResolve roster;
  resolveSystem = mkResolveSystem roster;
  resolveTrace = mkResolveTrace roster;
  resolveSystemTrace = mkResolveSystemTrace roster;
  resolveStrict = mkResolveStrict roster;
  resolveSystemStrict = mkResolveSystemStrict roster;
  resolveProfiled = mkResolveProfiled { } roster;
  resolveSystemProfiled = mkResolveSystemProfiled { } roster;

  # khion, as feltfomo, on an nvidia box -- enough to drive the host/user set
  # claims and a `when` predicate that reads a freeform host attribute.
  ctx = {
    host = {
      name = "khion";
      gpu = "nvidia";
    };
    user = {
      name = "feltfomo";
    };
  };
  # same user, other machine, no nvidia -- the miss side of every claim.
  ctxLumi = {
    host = {
      name = "lumi";
      gpu = "amd";
    };
    user = {
      name = "feltfomo";
    };
  };
  # grandpa building on the host he actually lives on -- for the exclude-self case.
  ctxGrandpa = {
    host = {
      name = "lumi";
      gpu = "amd";
    };
    user = {
      name = "grandpa";
    };
  };

  # host-only (system-scope) ctx - a real host, no user -- what a nixos slice
  # resolves under. "vm" is a host outside the claim, standing in for the
  # headless installer-test vm the compositor must stay off.
  ctxSystemKhion = {
    host = {
      name = "khion";
    };
  };
  ctxSystemVm = {
    host = {
      name = "vm";
    };
  };

  # strict-mode ctx fixtures - a host outside the roster, a user outside the
  # roster, an impossible but individually-valid pair (grandpa lives on
  # lumi, not khion), and an unknown-membership user (nomad, hosts = null)
  # that strict validation must still rescue rather than reject.
  ctxUnknownHost = {
    host = {
      name = "ghost";
    };
    user = {
      name = "feltfomo";
    };
  };
  ctxUnknownUser = {
    host = {
      name = "khion";
    };
    user = {
      name = "nobody";
    };
  };
  ctxImpossiblePair = {
    host = {
      name = "khion";
    };
    user = {
      name = "grandpa";
    };
  };
  ctxRescuedUnknownMembership = {
    host = {
      name = "khion";
    };
    user = {
      name = "nomad";
    };
  };
  ctxSystemUnknownHost = {
    host = {
      name = "ghost";
    };
  };

  run =
    c: units:
    let
      plain = resolve units c;
      traced = resolveTrace units c;
    in
    assert traced.value == plain;
    plain;

  runSystem =
    c: units:
    let
      plain = resolveSystem units c;
      traced = resolveSystemTrace units c;
    in
    assert traced.value == plain;
    plain;

  hostMissTrace = resolveTrace [
    {
      hosts = [ "khion" ];
      pkg = "khion-only";
    }
  ] ctxLumi;
  whenMissTrace = resolveTrace [
    {
      when = { host, ... }: host.gpu == "nvidia";
      pkg = "nvidia-only";
    }
  ] ctxLumi;
  labeledTrace = resolveTrace [
    {
      label = "khion-only-unit";
      hosts = [ "khion" ];
      pkg = "khion-only";
    }
  ] ctx;

  results = {
    global = run ctx [ { pkg = "everyone"; } ];

    hostHit = run ctx [
      {
        hosts = [ "khion" ];
        pkg = "khion-only";
      }
    ];
    hostMiss = run ctxLumi [
      {
        hosts = [ "khion" ];
        pkg = "khion-only";
      }
    ];

    userHit = run ctx [
      {
        users = [ "feltfomo" ];
        pkg = "feltfomo-only";
      }
    ];
    userMiss = run ctx [
      {
        users = [ "grandpa" ];
        pkg = "grandpa-only";
      }
    ];

    exceptHostActive = run ctx [
      {
        exceptHosts = [ "lumi" ];
        pkg = "not-lumi";
      }
    ];
    exceptHostInactive = run ctxLumi [
      {
        exceptHosts = [ "lumi" ];
        pkg = "not-lumi";
      }
    ];

    exceptUserActive = run ctx [
      {
        exceptUsers = [ "grandpa" ];
        pkg = "not-grandpa";
      }
    ];
    exceptUserInactive = run ctxGrandpa [
      {
        exceptUsers = [ "grandpa" ];
        pkg = "not-grandpa";
      }
    ];

    whenHit = run ctx [
      {
        when = { host, ... }: host.gpu == "nvidia";
        pkg = "nvidia-only";
      }
    ];
    whenMiss = run ctxLumi [
      {
        when = { host, ... }: host.gpu == "nvidia";
        pkg = "nvidia-only";
      }
    ];

    # a block owned by two hosts, narrowed inside to a user and to one host, with
    # an option-path unit alongside -- proves nesting narrows, list values merge,
    # and a dotted option path is just another value.
    nested = run ctx [
      {
        hosts = [
          "khion"
          "lumi"
        ];
        packages = [ "base" ];
        children = [
          {
            users = [ "feltfomo" ];
            packages = [ "feltfomo-extra" ];
          }
          {
            hosts = [ "khion" ];
            services.hypridle.enable = true;
          }
        ];
      }
    ];

    # a file-link entry as its own self-labeled unit, merged with a global one --
    # the same owner keys ride a file-link that ride a block.
    files = run ctx [
      {
        files = [
          {
            dest = ".config/a";
            src = "/a";
          }
        ];
      }
      {
        users = [ "feltfomo" ];
        files = [
          {
            dest = ".config/b";
            src = "/b";
          }
        ];
      }
    ];

    # a unit's label is author-facing identification only -- it must never
    # change what gets merged.
    labeledUnit = run ctx [
      {
        label = "khion-only-unit";
        hosts = [ "khion" ];
        pkg = "khion-only";
      }
    ];

    # host-only system scope - a compositor-shaped unit owned by two hosts,
    # resolved with only a host in ctx (no user), plus the off-claim miss.
    systemHostHit = runSystem ctxSystemKhion [
      {
        hosts = [
          "khion"
          "lumi"
        ];
        programs.hyprland.enable = true;
      }
    ];
    systemHostMiss = runSystem ctxSystemVm [
      {
        hosts = [
          "khion"
          "lumi"
        ];
        programs.hyprland.enable = true;
      }
    ];

    # value escape hatch - users.* is both a claim key and a real nixos option
    # path, so this is the motivating collision -- global (untagged), so it's
    # not run through a host/user claim at all.
    valueEscapeHatch = run ctx [
      {
        value = {
          users.users.alice = {
            isNormalUser = true;
          };
        };
      }
    ];

    # same payload, now narrowed by a host claim -- proves a claim still
    # narrows around a value block instead of being swallowed by it.
    valueEscapeHatchHit = run ctx [
      {
        hosts = [ "khion" ];
        value = {
          users.users.alice = {
            isNormalUser = true;
          };
        };
      }
    ];
    valueEscapeHatchMiss = run ctxLumi [
      {
        hosts = [ "khion" ];
        value = {
          users.users.alice = {
            isNormalUser = true;
          };
        };
      }
    ];

    # translate only intercepts a unit's own top-level keys -- reserved-looking
    # names sitting *inside* a value block are never re-scanned as claims, so
    # nothing here gets silently dropped despite the name collision.
    valueNoSwallow = run ctx [
      {
        value = {
          hosts = "not-a-claim-this-is-config";
          when = "also-just-a-string";
        };
      }
    ];

    # a value + children node must merge identically to the pre-existing
    # inline-config + children node above (`nested`) -- same claims, same
    # shape, config just routed through the hatch instead of inline.
    nestedViaValue = run ctx [
      {
        hosts = [
          "khion"
          "lumi"
        ];
        value = {
          packages = [ "base" ];
        };
        children = [
          {
            users = [ "feltfomo" ];
            value = {
              packages = [ "feltfomo-extra" ];
            };
          }
          {
            hosts = [ "khion" ];
            value = {
              services.hypridle.enable = true;
            };
          }
        ];
      }
    ];
  };

  # deepseq drives the lazy check/merge throws so tryeval catches the impossible
  # case below.
  throws = x: !(builtins.tryEval (builtins.deepSeq x x)).success;

  defaultEngineArgs = resolveLib.engineArgsFor roster;
  projectedUserCtx = axes.contextFor defaultEngineArgs.registry (ctx // { unrelated = "private"; });
  projectedSystemCtx = axes.contextFor defaultEngineArgs.registry (
    ctxSystemKhion // { unrelated = "private"; }
  );

  tests = {
    "test default registry projects the byte-identical bounded user and system contexts" = {
      expr =
        projectedUserCtx == {
          inherit (ctx) host user;
        }
        &&
          projectedSystemCtx == {
            inherit (ctxSystemKhion) host;
            user = null;
          };
      expected = true;
    };
    "test default descriptors preserve the public key, registry, and roster shapes" = {
      expr =
        claimKeys == [
          "hosts"
          "users"
          "exceptHosts"
          "exceptUsers"
          "when"
        ]
        &&
          builtins.attrNames defaultEngineArgs.registry == [
            "host"
            "user"
            "when"
          ]
        &&
          builtins.attrNames roster == [
            "aliases"
            "dimensions"
            "display"
            "hosts"
            "membership"
            "users"
            "usersWithUnknownMembership"
          ];
      expected = true;
    };
    "test untagged is global" = {
      expr = results.global;
      expected = {
        pkg = "everyone";
      };
    };
    "test host hit" = {
      expr = results.hostHit;
      expected = {
        pkg = "khion-only";
      };
    };
    "test host miss drops" = {
      expr = results.hostMiss;
      expected = { };
    };
    "test user hit" = {
      expr = results.userHit;
      expected = {
        pkg = "feltfomo-only";
      };
    };
    "test user miss drops" = {
      expr = results.userMiss;
      expected = { };
    };
    "test exceptHosts active" = {
      expr = results.exceptHostActive;
      expected = {
        pkg = "not-lumi";
      };
    };
    "test exceptHosts inactive drops" = {
      expr = results.exceptHostInactive;
      expected = { };
    };
    "test exceptUsers active" = {
      expr = results.exceptUserActive;
      expected = {
        pkg = "not-grandpa";
      };
    };
    "test exceptUsers inactive drops" = {
      expr = results.exceptUserInactive;
      expected = { };
    };
    "test when hit" = {
      expr = results.whenHit;
      expected = {
        pkg = "nvidia-only";
      };
    };
    "test when miss drops" = {
      expr = results.whenMiss;
      expected = { };
    };
    "test a throwing when predicate fails through the contextual selector boundary" = {
      expr = resolve [
        {
          label = "evil-predicate";
          when = _ctx: throw "boom, this predicate is evil";
          pkg = "never";
        }
      ] ctx;
      expectedError.type = "ThrownError";
      expectedError.msg = "boom, this predicate is evil";
    };
    "test nested narrow + merge + option path" = {
      expr = results.nested;
      expected = {
        packages = [
          "base"
          "feltfomo-extra"
        ];
        services.hypridle.enable = true;
      };
    };
    "test file-link entries merge across units" = {
      expr = results.files;
      expected = {
        files = [
          {
            dest = ".config/a";
            src = "/a";
          }
          {
            dest = ".config/b";
            src = "/b";
          }
        ];
      };
    };
    "test label never leaks into merged output" = {
      expr = results.labeledUnit;
      expected = {
        pkg = "khion-only";
      };
    };
    "test label/source are optional plain-string identification, not claims or config" = {
      expr = translate {
        label = "my-unit";
        source = "modules/foo.nix";
        pkg = "x";
      };
      expected = {
        claim = { };
        value = {
          pkg = "x";
        };
        label = "my-unit";
        source = "modules/foo.nix";
      };
    };
    "test metadata-only terminal units fail instead of silently disappearing" = {
      expr =
        throws (translate {
          label = "orphan";
        })
        && throws (translate {
          hosts = [ "khion" ];
        });
      expected = true;
    };
    "test a contradictory metadata-only unit fails before selection" = {
      expr = resolve [
        {
          label = "impossible-empty-unit";
          hosts = [ "khion" ];
          exceptHosts = [ "khion" ];
        }
      ] ctxLumi;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/claim-polarity\\] a unit cannot set both 'hosts' and 'exceptHosts' -- pick the set or its complement";
    };
    "test a claim-only parent remains valid when it narrows a real child" = {
      expr = resolve [
        {
          label = "claim-wrapper";
          hosts = [ "khion" ];
          children = [ { pkg = "nested"; } ];
        }
      ] ctx;
      expected = {
        pkg = "nested";
      };
    };
    "test a non-string label throws at author time" = {
      expr = translate {
        label = 123;
        pkg = "x";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-label\\] 'label' must be a plain string; got int";
    };
    "test a non-string source throws at author time" = {
      expr = translate {
        source = { };
        pkg = "x";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-source\\] 'source' must be a plain string; got set";
    };
    "test label/source don't inherit to children" = {
      expr =
        let
          t = translate {
            label = "parent";
            pkg = "x";
            children = [ { pkg = "y"; } ];
          };
          child = builtins.head t.children;
        in
        t.label == "parent" && !(child ? label);
      expected = true;
    };
    "test cross-host user claim still impossible through the surface" = {
      expr = run ctx [
        {
          hosts = [ "khion" ];
          children = [
            {
              users = [ "grandpa" ];
              pkg = "x";
            }
          ];
        }
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ pkg \\}: no user in \\{ grandpa \\} lives on any host in \\{ standalone/khion \\} -- this host/user c";
    };
    "test misshaped reserved key throws at author time" = {
      expr = run ctx [
        {
          users = {
            alice = { };
          };
          pkg = "x";
        }
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 'users' must be a list of names; got set\\. a reserved ownership key can't also be a config path on ";
    };
    "test system scope resolves a host-narrowed unit with no user bound" = {
      expr = results.systemHostHit;
      expected = {
        programs.hyprland.enable = true;
      };
    };
    "test system scope drops a host-narrowed unit off its claimed hosts" = {
      expr = results.systemHostMiss;
      expected = { };
    };
    "test system scope rejects a users claim at author time" = {
      expr = resolveSystem [
        {
          hosts = [ "khion" ];
          users = [ "feltfomo" ];
          programs.hyprland.enable = true;
        }
      ] ctxSystemKhion;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: a system-scope \\(host-only\\) unit sets 'users' = \\[\"feltfomo\"\\] -- a host-only slice binds no user, so";
    };
    "test system scope rejects an exceptUsers claim at author time" = {
      expr = resolveSystem [
        {
          exceptUsers = [ "grandpa" ];
          programs.hyprland.enable = true;
        }
      ] ctxSystemKhion;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: a system-scope \\(host-only\\) unit sets 'exceptUsers' = \\[\"grandpa\"\\] -- a host-only slice binds no use";
    };
    "test value escape hatch routes users.* as ordinary config" = {
      expr = results.valueEscapeHatch;
      expected = {
        users.users.alice = {
          isNormalUser = true;
        };
      };
    };
    "test a claim narrows around a value block (hit)" = {
      expr = results.valueEscapeHatchHit;
      expected = {
        users.users.alice = {
          isNormalUser = true;
        };
      };
    };
    "test a claim narrows around a value block (miss drops)" = {
      expr = results.valueEscapeHatchMiss;
      expected = { };
    };
    "test value block content is never re-scanned for claim keys" = {
      expr = results.valueNoSwallow;
      expected = {
        hosts = "not-a-claim-this-is-config";
        when = "also-just-a-string";
      };
    };
    "test value + children matches the inline-config + children shape" = {
      expr = results.nestedViaValue;
      expected = results.nested;
    };
    "test value mixed with inline config throws at author time" = {
      expr = run ctx [
        {
          value = {
            users.users.alice = {
              isNormalUser = true;
            };
          };
          pkg = "x";
        }
      ];
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-mixed-value\\] a unit cannot mix a 'value' block with inline config keys \\(pkg\\) -- route everyth";
    };
    "test strict rejects an unknown host name" = {
      expr = resolveStrict [ { pkg = "x"; } ] ctxUnknownHost;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'ghost', user 'feltfomo'': axis 'host' claim can never be satisfied \\(disjoint nest";
    };
    "test strict rejects an unknown user name" = {
      expr = resolveStrict [ { pkg = "x"; } ] ctxUnknownUser;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'khion', user 'nobody'': axis 'user' claim can never be satisfied \\(disjoint nest o";
    };
    "test strict rejects a known but impossible host x user pair" = {
      expr = resolveStrict [ { pkg = "x"; } ] ctxImpossiblePair;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'khion', user 'grandpa'': no user in \\{ grandpa \\} lives on any host in \\{ standalone";
    };
    "test strict rescues an unknown-membership user instead of rejecting it" = {
      expr = resolveStrict [ { pkg = "x"; } ] ctxRescuedUnknownMembership;
      expected = {
        pkg = "x";
      };
    };
    "test strict permissive path is byte-identical to the non-strict resolve" = {
      expr = resolveStrict [
        {
          hosts = [ "khion" ];
          pkg = "khion-only";
        }
      ] ctx;
      expected = results.hostHit;
    };
    "test system-scope strict validates the host only and still resolves" = {
      expr = resolveSystemStrict [
        {
          hosts = [
            "khion"
            "lumi"
          ];
          programs.hyprland.enable = true;
        }
      ] ctxSystemKhion;
      expected = results.systemHostHit;
    };
    "test system-scope strict rejects an unknown host" = {
      expr = resolveSystemStrict [
        {
          hosts = [
            "khion"
            "lumi"
          ];
          programs.hyprland.enable = true;
        }
      ] ctxSystemUnknownHost;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'ghost'': axis 'host' claim can never be satisfied \\(disjoint nest or unknown name\\)";
    };
    "test trace names host as the rejecting axis" = {
      expr =
        let
          leaf = builtins.head hostMissTrace.trace;
        in
        hostMissTrace.value == results.hostMiss
        && leaf.rejectedBy == [ "host" ]
        && leaf.axisResults.host.decision == "rejected";
      expected = true;
    };
    "test trace names predicate rejection without inventing members" = {
      expr =
        let
          leaf = builtins.head whenMissTrace.trace;
        in
        whenMissTrace.value == results.whenMiss
        && leaf.rejectedBy == [ "when" ]
        && leaf.axisResults.when.decision == "rejected"
        && !(leaf.axisResults.when.details ? materializedMembers);
      expected = true;
    };
    "test trace reuses diagnostic identity and reports pre-merge contribution" = {
      expr =
        let
          leaf = builtins.head labeledTrace.trace;
        in
        labeledTrace.value == results.labeledUnit
        && leaf.identity == "unit 'khion-only-unit'"
        && leaf.preMergeContribution.stage == "pre-merge"
        && leaf.preMergeContribution.offeredPaths == [ "pkg" ];
      expected = true;
    };
    "test plain and trace surface entries both preserve impossible claims" = {
      expr =
        let
          units = [
            {
              hosts = [ "khion" ];
              children = [
                {
                  users = [ "grandpa" ];
                  pkg = "x";
                }
              ];
            }
          ];
        in
        throws (resolve units ctx) && throws (resolveTrace units ctx);
      expected = true;
    };
    "test profiled surface applies unanimous unit selection" = {
      expr = resolveProfiled [
        {
          mergeProfile = "last-wins";
          port = 80;
        }
        {
          mergeProfile = "last-wins";
          port = 443;
        }
      ] ctx;
      expected = {
        port = 443;
      };
    };
    "test profiled system surface applies unanimous unit selection" = {
      expr = resolveSystemProfiled [
        {
          mergeProfile = "last-wins";
          port = 80;
        }
        {
          mergeProfile = "last-wins";
          port = 443;
        }
      ] ctxSystemKhion;
      expected = {
        port = 443;
      };
    };
    "test profiled surface rejects unknown profiles on inactive units" = {
      expr = resolveProfiled [
        {
          hosts = [ "lumi" ];
          mergeProfile = "missing";
          pkg = "inactive";
        }
      ] ctx;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-merge-profile-unknown\\] unknown merge profile 'missing'";
    };
    "test default surface reserves mergeProfile without enabling it" = {
      expr = resolve [
        {
          mergeProfile = "last-wins";
          pkg = "kept";
        }
      ] ctx;
      expected = {
        pkg = "kept";
      };
    };
    "test a parent merge profile doesn't inherit into child contributors" = {
      expr = resolveProfiled [
        {
          mergeProfile = "last-wins";
          children = [
            { port = 80; }
            { port = 443; }
          ];
        }
      ] ctx;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/merge/conflict\\] conflict at port: co-owners \"unlabeled unit \\{ port \\}\" set differing values";
    };
    "test a unit must be an attribute set" = {
      expr = translate "not-a-unit";
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-shape\\] a unit must be an attribute set; got string";
    };
    "test children must be a list" = {
      expr = translate {
        children = { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-children\\] 'children' must be a list of unit attribute sets";
    };
    "test children must contain unit attribute sets" = {
      expr = translate {
        children = [ 1 ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-children\\] 'children' must be a list of unit attribute sets";
    };
    "test value escape hatch requires an attribute set" = {
      expr = translate {
        value = "not-config";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-value\\] 'value' must be an attribute set; got string";
    };
  };

in
{
  inherit results tests;
}
