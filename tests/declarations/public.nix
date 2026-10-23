{
  lib,
  pkgs,
  axiom,
  krisis,
  lexicon,
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  extension = import ./fixtures/bookmarks.nix;
  api = lexicon.lib.lexicon.configure { extensions = [ extension ]; };
  inherit (api) ownerships;
  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { inherit system; })
    (ownerships.define.host "lumi" { inherit system; })
    (ownerships.define.user "alice" {
      hosts = [
        "khion"
        "lumi"
      ];
    })
    (ownerships.define.role "desktop")
    (ownerships.define.role "laptop")
  ];
  target = {
    host = {
      name = "khion";
      inherit system;
      id = "${system}/khion";
    };
    user = {
      name = "alice";
      home = "/srv/alice";
    };
  };
  args = target // {
    inherit lib pkgs;
    config = {
      networking.hostName = "khion";
      lexicon.furnish.declarations = [ { } ];
      resourceOnly = "native-resource-context";
    };
  };
  owned = api.forRoster {
    inherit roster;
    selectionContext = _: { role.name = "desktop"; };
  };
  direct = api.forTarget { inherit target; };
  link = {
    source = "/srv/editable/book";
    destination = ".bookmarks/book";
  };
  source = ../program/fixtures/sample-tree;
  declarations =
    aspect:
    (builtins.head (
      builtins.filter (module: builtins.isAttrs module && module ? lexicon) (aspect.nixos args).imports
    )).lexicon.furnish.declarations;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  selected = owned {
    hosts = [ "khion" ];
    roles = [ "desktop" ];
    metadata.tags = [ "root" ];
    bookmarks = {
      metadata.tags = [ "block" ];
      entries = [ (link // { roles = [ "desktop" ]; }) ];
    };
    furnish = {
      roles = [ "desktop" ];
      links = [
        (
          link
          // {
            destination = ".other/book";
            when = ctx: ctx.role.name == "desktop";
          }
        )
      ];
    };
    theme = {
      id = "role";
      renderers.noctalia = {
        roles = [ "desktop" ];
        source = source + "/safe-render.nix";
        output = ".config/role";
      };
    };
  };
  selectedEntries = declarations selected;
  legacy = lexicon.lib.programOwnerships { inherit roster; };
  canonicalPlain = lexicon.lib.lexicon.forRoster { inherit roster; };
  canonicalSpec = {
    furnish.links = [ link ];
  };
  legacySpec = {
    links = [
      {
        target = link.source;
        dest = link.destination;
      }
    ];
  };
  den = {
    hosts.${system}.khion.users.alice = throw "forced Den user";
  };
  denPlain = lexicon.lib.lexicon.forDen { inherit den; };
  advanced = api.withResolvers {
    resolvers =
      ownerships:
      let
        r = ownerships.mkResolvers roster;
      in
      {
        inherit (r) resolve resolveSystem;
        resolvePrepared = r.prepared;
      };
    selectionContext = _: { role.name = "desktop"; };
    filePrincipals = { user, ... }: [
      {
        authority = {
          scope = "user";
          identity = user.name;
        };
        managedRoot = user.home;
      }
    ];
    hostUserNames = _: [ "alice" ];
  };
  hostTarget = lexicon.lib.lexicon.forTarget {
    target.host = target.host;
    mkCoordinator = throw "forced coordinator";
  };
  noContext = api.forRoster { inherit roster; };
  unusedContext = api.forRoster {
    inherit roster;
    selectionContext = _: throw "forced unused extra context";
  };
  invalidContext = api.forRoster {
    inherit roster;
    selectionContext = _: {
      host = { };
      role.name = "desktop";
    };
  };
  nonRecordContext = api.forRoster {
    inherit roster;
    selectionContext = _: [ ];
  };
  nested =
    depth: payload:
    if depth == 0 then { value = payload; } else { children = [ (nested (depth - 1) payload) ]; };
  recursiveSystem = owned {
    users = [ "alice" ];
    nixos = [ (nested 5 { services.deep.enabled = true; }) ];
  };
  inactiveSystem = owned {
    nixos = [
      {
        hosts = [ "lumi" ];
        children = _: throw "inactive children";
        value = throw "inactive native unit";
      }
    ];
  };
  mixedExtension = { definitions, ... }: {
    name = "mixed";
    blocks = [
      {
        name = "mixed";
        scope = "user";
        outputs = [
          "homeManager"
          "resources"
        ];
        node = definitions.record {
          children = {
            files = definitions.forOutputs [ "resources" ] (
              definitions.collection {
                contextual = true;
                item = definitions.record {
                  fields = {
                    source = { };
                    destination = { };
                  };
                };
              }
            );
            native = definitions.forOutputs [ "homeManager" ] (
              definitions.native {
                owner = "Home Manager";
                validate = lib.isFunction;
              }
            );
          };
        };
        lower =
          {
            value,
            origins,
            context,
            ...
          }:
          if context.output == "resources" then
            {
              resources = lib.imap0 (index: entry: {
                kind = "external-link";
                value = entry;
                origin = (builtins.elemAt origins.children.files index).self;
              }) (value.files or [ ]);
            }
          else
            {
              homeManager = [
                {
                  module = value.native;
                  origin = origins.children.native;
                }
              ];
            };
      }
    ];
  };
  mixedApi = lexicon.lib.lexicon.configure { extensions = [ mixedExtension ]; };
  mixed = (mixedApi.forTarget { inherit target; }) {
    mixed = {
      files = { config, ... }: [ (link // { source = "/${config.resourceOnly}"; }) ];
      native = { custom, ... }: {
        options.test = lib.mkOption { type = lib.types.str; };
        config.test = custom;
      };
    };
  };
  mixedHome =
    (lib.evalModules {
      modules = [
        mixed.homeManager
        { _module.args.custom = "home-argument"; }
      ];
      specialArgs = { inherit pkgs; };
    }).config;
  furnish = lexicon.lib.furnish {
    resolve = _: _: { };
    resolveSystem = _: _: { };
  };
  targets = import ../../src/furnish/target.nix { inherit lib; };
  executor = {
    identity = "test/symlink";
    priority = 0;
    enabled = true;
    protocolVersion = 1;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize = declaration: {
      target = targets.materialize declaration;
      cleanupStrategy = "exact-symlink-target";
      selfHealStrategy = "exact-symlink-target";
    };
  };
  collide = declarations (owned {
    bookmarks.entries = [ link ];
    furnish.links = [ link ];
  });
  compiler = import ../../src/declarations { inherit lib axiom krisis; };
  owners = import ../../src/lexicon/resources.nix { inherit lib axiom krisis; };
  internal = compiler.configure {
    extensions = [ extension ];
    blocks = import ../../src/lexicon/builtins.nix {
      inherit lib axiom krisis;
      resources = owners;
      systemOwner = import ../../src/lexicon/system.nix {
        inherit lib axiom krisis;
        inherit (compiler) definitions;
      };
      inherit (compiler) definitions;
    };
  };
  validate =
    declaration:
    ((internal.bind { inherit roster; }).prepare declaration).validate {
      scope = "user";
      outputs = [ "resources" ];
      context = args // {
        role.name = "desktop";
        output = "resources";
      };
    };
  plans =
    declaration:
    ((internal.bind { inherit roster; }).prepare declaration).compile {
      scope = "user";
      outputs = [ "resources" ];
      context = args // {
        role.name = "desktop";
        output = "resources";
      };
    };
  locations = result: map (diagnostic: diagnostic.primary.label) result.diagnostics;
  selectedTemplate =
    (plans {
      theme = {
        id = "origins";
        templates = [
          {
            hosts = [ "lumi" ];
            renderers.noctalia = {
              source = throw "inactive template source";
              output = "unused";
            };
          }
          {
            renderers.noctalia = {
              source = 1;
              output = ".selected";
            };
          }
        ];
      };
    }).resources;
  sharedTemplate =
    (plans {
      theme = {
        id = "origins";
        renderers.noctalia = {
          source = source + "/safe-render.nix";
          output = ".selected";
          sharedWith = [ "dms" ];
        };
      };
    }).resources;
  recursiveExtension = node: { definitions, ... }: {
    name = "recursive-test";
    blocks = [
      {
        name = "tree";
        scope = "user";
        outputs = [ "resources" ];
        node = node definitions;
        lower = _: { };
      }
    ];
  };
  badMixed = { definitions, ... }: {
    name = "bad-mixed";
    blocks = [
      {
        name = "bad";
        scope = "user";
        outputs = [
          "homeManager"
          "resources"
        ];
        node = definitions.record { };
        lower = _: {
          resources = [
            {
              kind = "external-link";
              value = link;
              origin = [ "bad" ];
            }
          ];
        };
      }
    ];
  };
  wrongProjection =
    ((lexicon.lib.lexicon.configure { extensions = [ badMixed ]; }).forTarget { inherit target; })
      { bad = { }; };
  reservedAxis =
    args:
    let
      ext = extension args;
    in
    ext
    // {
      ownership = map (
        descriptor:
        descriptor // { axisFor = roster: (descriptor.axisFor roster) // { ctxKey = "config"; }; }
      ) ext.ownership;
    };
  oldDirect = lexicon.lib.programDirect { inherit target; };
  nativeDirect = oldDirect {
    nixos = [
      ./fixtures/native-system.nix
      ({ pkgs, ... }: { config.nativeResult.callback = pkgs.hello.pname; })
    ];
  };
  evaluatedDirect =
    (lib.evalModules {
      modules = [ nativeDirect.nixos ];
      specialArgs = removeAttrs args [ "config" ];
    }).config.nativeResult;
  inheritedTemplate =
    (plans {
      theme = {
        id = "inherited";
        source = 1;
        renderers.noctalia = {
          output = ".inherited";
        };
      };
    }).resources;
  overriddenTemplate =
    (plans {
      theme = {
        id = "overridden";
        source = source + "/safe-render.nix";
        renderers.noctalia = {
          source = 1;
          output = ".overridden";
        };
      };
    }).resources;
  roleNative = owned {
    roles = [ "desktop" ];
    homeManager = { lib, role, ... }: {
      options.nativeRole = lib.mkOption { type = lib.types.str; };
      config.nativeRole = role;
    };
  };
  systemObserver = api.withResolvers {
    resolvers =
      ownerships:
      let
        r = ownerships.mkResolvers roster;
      in
      {
        inherit (r) resolve;
        resolvePrepared = r.prepared;
        resolveSystem =
          units: context:
          assert context.user == null;
          r.resolveSystem units context;
      };
    filePrincipals = _: [ ];
    hostUserNames = _: [ ];
  };
  hostWhen =
    factory:
    (factory {
      nixos = callback: [
        {
          when = ctx: ctx.user == null;
          value.services.hostWhen = callback.user.name;
        }
      ];
    }).nixos
      args;
  tests =
    (import ./links.nix {
      inherit
        lib
        pkgs
        direct
        owned
        declarations
        fails
        owners
        furnish
        executor
        link
        ;
    })
    // (import ./contextual-theme.nix {
      inherit
        lib
        pkgs
        lexicon
        owned
        direct
        hostTarget
        target
        args
        roster
        declarations
        fails
        plans
        validate
        locations
        owners
        compiler
        ;
    })
    // {
      den-extra-roster-shape-fails = fails (
        api.forDen {
          inherit den;
          selectionRoster = [ ];
        }
      );
      nonboolean-resource-intent-has-diagnostic = fails (
        (lexicon.lib.lexicon.configure {
          extensions = [
            ({ definitions, ... }: {
              name = "invalid-intent";
              blocks = [
                {
                  name = "invalid";
                  scope = "user";
                  outputs = [ "resources" ];
                  node = definitions.record { };
                  resourceIntent = _: 1;
                  lower = _: { };
                }
              ];
            })
          ];
        }).forTarget
          { inherit target; }
          { invalid = { }; }
      );
      target-host-diagnostic-has-field-path =
        locations (
          (import ../../src/lexicon/target.nix { inherit lib axiom krisis; }).validate {
            host = target.host // {
              name = 1;
            };
          }
        ) == [ "$.target.host.name" ];
      target-user-diagnostic-has-field-path =
        locations (
          (import ../../src/lexicon/target.nix { inherit lib axiom krisis; }).validate (
            target
            // {
              user = target.user // {
                home = "relative";
              };
            }
          )
        ) == [ "$.target.user.home" ];
      system-predicates-see-null-user-and-callbacks-keep-user =
        (hostWhen owned).services.hostWhen == "alice";
      den-system-predicates-see-null-user = (hostWhen denPlain).services.hostWhen == "alice";
      advanced-system-selection-and-merge-see-null-user =
        (hostWhen systemObserver).services.hostWhen == "alice";
      advanced-system-predicates-see-null-user = (hostWhen advanced).services.hostWhen == "alice";
      direct-system-callback-keeps-bound-user =
        ((direct { nixos = callback: [ { value.services.callbackUser = callback.user.name; } ]; }).nixos
          args
        ).imports == [ { services.callbackUser = "alice"; } ];
      native-role-argument-remains-owned-by-module-system =
        (lib.evalModules {
          modules = [
            roleNative.homeManager
            { _module.args.role = "native-role-argument"; }
          ];
          specialArgs = removeAttrs args [ "config" ];
        }).config.nativeRole == "native-role-argument";
      inherited-theme-source-retains-field-origin =
        locations (owners.validatePlan (builtins.head inheritedTemplate)) == [ "$.theme.source" ];
      overridden-theme-source-retains-field-origin =
        locations (owners.validatePlan (builtins.head overriddenTemplate))
        == [ "$.theme.renderers.noctalia.source" ];
      mixed-wrong-output-is-rejected = fails (wrongProjection.homeManager args);
      empty-legacy-imports-are-inert = oldDirect { imports = [ ]; } == { };
      empty-canonical-theme-is-inert-without-user =
        hostTarget {
          theme = {
            id = "empty";
            templates = [ ];
          };
        } == { };
      empty-legacy-theme-is-inert-without-user =
        (lexicon.lib.programDirect { target.host = target.host; }) {
          theme = {
            id = "empty";
            templates = [ ];
          };
        } == { };
      empty-theme-mixed-fields-fail = fails (hostTarget {
        theme = {
          id = "empty";
          templates = [ ];
          source = throw "must not read mixed source";
        };
      });
      legacy-direct-native-functions-and-paths-remain-modules =
        evaluatedDirect == {
          path = true;
          callback = "hello";
        };
      legacy-owned-mixed-value-fails-even-when-inactive = fails (
        (legacy {
          nixos = [
            {
              hosts = [ "lumi" ];
              value.answer = 1;
              services.answer = true;
            }
          ];
        }).nixos
          args
      );
      legacy-owned-malformed-users-remain-errors = fails (
        (legacy { nixos = [ { users.users.alice.isNormalUser = true; } ]; }).nixos args
      );
      canonical-direct-native-function-and-path-values-work =
        (lib.evalModules {
          modules = [
            (direct {
              nixos = [
                { value = ./fixtures/native-system.nix; }
                { value = { pkgs, ... }: { config.nativeResult.callback = pkgs.hello.pname; }; }
              ];
            }).nixos
          ];
          specialArgs = removeAttrs args [ "config" ];
        }).config.nativeResult == evaluatedDirect;
      recursive-wrapper-only-cycle-fails = fails (
        (lexicon.lib.lexicon.configure {
          extensions = [ (recursiveExtension (d: d.recursive (self: d.forOutputs [ "resources" ] self))) ];
        }).forTarget
          { inherit target; }
          { }
      );
      malformed-recursive-binder-fails = fails (
        (lexicon.lib.lexicon.configure {
          extensions = [
            (recursiveExtension (_: {
              kind = "recursive";
              body = "bad";
            }))
          ];
        }).forTarget
          { inherit target; }
          { }
      );
      recursive-wrapper-unknown-field-fails = fails (
        (lexicon.lib.lexicon.configure {
          extensions = [ (recursiveExtension (d: (d.recursive (_: d.record { })) // { unknown = true; })) ];
        }).forTarget
          { inherit target; }
          { }
      );
      reference-outside-binder-fails = fails (
        (lexicon.lib.lexicon.configure {
          extensions = [
            (recursiveExtension (_: {
              kind = "reference";
              name = "outside";
            }))
          ];
        }).forTarget
          { inherit target; }
          { }
      );
      builtin-file-diagnostic-keeps-authored-index =
        locations (validate {
          furnish.files = [
            {
              hosts = [ "lumi" ];
              source = throw "inactive";
              destination = "inactive";
            }
            {
              inherit source;
              destination = 1;
            }
          ];
        }) == [ "$.furnish.files[1].destination" ];
      builtin-file-missing-source-has-field-path =
        locations (validate {
          furnish.files = [ { destination = "missing"; } ];
        }) == [ "$.furnish.files[0].source" ];
      builtin-directory-diagnostic-has-field-path =
        locations (validate {
          furnish.directories = [
            {
              inherit source;
              destination = 1;
            }
          ];
        }) == [ "$.furnish.directories[0].destination" ];
      builtin-override-diagnostic-keeps-authored-index =
        locations (validate {
          furnish.directories = [
            {
              inherit source;
              destination = ".tree";
              files = [
                {
                  hosts = [ "lumi" ];
                  names = [ "inactive" ];
                }
                { names = 1; }
              ];
            }
          ];
        }) == [ "$.furnish.directories[0].files[1].names" ];
      theme-id-diagnostic-has-field-path =
        locations (validate {
          theme = {
            id = 1;
            renderers.noctalia = {
              inherit source;
              output = "x";
            };
          };
        }) == [ "$.theme.id" ];
      selected-theme-diagnostic-keeps-original-template-and-renderer =
        locations (owners.validatePlan (builtins.head selectedTemplate))
        == [ "$.theme.templates[1].renderers.noctalia.source" ];
      shared-renderers-retain-their-origin =
        builtins.length sharedTemplate == 2
        && builtins.all (
          plan:
          plan.origin == [
            "theme"
            "renderers"
            "noctalia"
          ]
        ) sharedTemplate;
      all-inactive-renderers-produce-no-plans =
        declarations (owned {
          theme = {
            id = "inactive";
            renderers.noctalia = {
              roles = [ "laptop" ];
              source = throw "inactive renderer";
              output = "x";
            };
          };
        }) == [ ];
      authored-empty-renderers-remain-invalid = fails (
        declarations (owned {
          theme = {
            id = "empty";
            renderers = { };
          };
        })
      );
      reserved-axis-context-fails-at-binding = fails (
        (lexicon.lib.lexicon.configure { extensions = [ reservedAxis ]; }).forRoster { inherit roster; }
      );
      den-extra-roster-cannot-replace-base = fails (
        api.forDen {
          inherit den;
          selectionRoster.hosts = [ ];
        }
      );
      factory-is-plain-function = builtins.isFunction owned && builtins.isFunction direct;
      all-registered-resources-share-selection =
        builtins.length selectedEntries == 4
        && builtins.all (
          entry:
          entry.authority.identity == "alice"
          && entry.managedRoot == "/srv/alice"
          && entry.filesystemNamespace == target.host.id
        ) selectedEntries;
      canonical-and-legacy-manifests-match =
        declarations (canonicalPlain canonicalSpec) == declarations (legacy legacySpec);
      canonical-direct-and-roster-match =
        declarations ((lexicon.lib.lexicon.forTarget { inherit target; }) canonicalSpec)
        == declarations (canonicalPlain canonicalSpec);
      den-binding-keeps-principal =
        (builtins.head (declarations (denPlain canonicalSpec))).authority.identity == "alice";
      advanced-binding-uses-configured-vocabulary =
        builtins.length (
          declarations (advanced {
            roles = [ "desktop" ];
            bookmarks.entries = [ link ];
          })
        ) == 1;
      missing-context-fails = fails (
        declarations (noContext {
          bookmarks = {
            roles = [ "desktop" ];
            entries = [ link ];
          };
        })
      );
      unknown-context-key-fails-when-demanded = fails (
        declarations (invalidContext {
          furnish = {
            roles = [ "desktop" ];
            links = [ link ];
          };
        })
      );
      nonrecord-context-fails-when-demanded = fails (
        declarations (nonRecordContext {
          roles = [ "desktop" ];
          furnish.links = [ link ];
        })
      );
      unclaimed-extra-context-stays-lazy =
        builtins.length (declarations (unusedContext canonicalSpec)) == 1;
      inactive-custom-callback-stays-lazy =
        declarations (owned {
          roles = [ "laptop" ];
          bookmarks.entries = _: throw "inactive callback";
        }) == [ ];
      block-and-entry-narrowing =
        declarations (owned {
          furnish = {
            roles = [ "laptop" ];
            links = [ (link // { source = throw "inactive source"; }) ];
          };
        }) == [ ];
      metadata-validates-on-builtins = fails (
        declarations (owned {
          furnish = {
            metadata.tags = 1;
            links = [ link ];
          };
        })
      );
      direct-rejects-custom-static-claim = fails (direct {
        furnish.links = [ (link // { roles = [ "desktop" ]; }) ];
      });
      direct-rejects-custom-dynamic-claim = fails (
        declarations (direct {
          furnish.links = _: [ (link // { roles = [ "desktop" ]; }) ];
        })
      );
      host-only-native-remains-lazy =
        builtins.attrNames (hostTarget {
          package = p: p.hello;
        }) == [ "homeManager" ];
      empty-collection-callback-needs-user = fails (hostTarget {
        furnish.links = _: [ ];
      });
      empty-static-collection-is-inert = hostTarget { furnish.links = [ ]; } == { };
      recursive-system-unit-selects-and-merges = (recursiveSystem.nixos args).services.deep.enabled;
      inactive-recursive-callback-and-native-stay-lazy = inactiveSystem.nixos args == { };
      static-forbidden-deep-descendant-fails-before-filter = fails (
        (owned {
          nixos = [
            {
              hosts = [ "lumi" ];
              children = [ ((nested 4 { }) // { roles = [ "desktop" ]; }) ];
            }
          ];
        }).nixos
          args
      );
      dynamic-recursive-descendants-work =
        (
          (owned { nixos = [ { children = _: [ (nested 3 { services.dynamic.enabled = true; }) ]; } ]; })
          .nixos
          args
        ).services.dynamic.enabled;
      direct-recursive-custom-claim-fails = fails (direct {
        nixos = [ { children = [ ((nested 4 { }) // { roles = [ "desktop" ]; }) ]; } ];
      });
      scalar-unit-conflicts-remain-errors = fails (
        (owned {
          nixos = [
            { value.answer = 1; }
            { value.answer = 2; }
          ];
        }).nixos
          args
      );
      native-priorities-remain-native =
        (lib.evalModules {
          modules = [
            (owned {
              nixos = [
                {
                  value = {
                    options.answer = lib.mkOption { type = lib.types.int; };
                    config.answer = lib.mkDefault 1;
                  };
                }
              ];
            }).nixos
            { config.answer = lib.mkForce 2; }
          ];
          specialArgs = removeAttrs args [ "config" ];
        }).config.answer == 2;
      native-ownership-looking-fields-stay-opaque =
        ((direct { nixos = [ { value.users.users.alice.isNormalUser = true; } ]; }).nixos args).imports
        == [ { users.users.alice.isNormalUser = true; } ];
      mixed-home-does-not-force-resource-callback = mixedHome.test == "home-argument";
      mixed-resource-gets-system-config =
        (builtins.head (declarations mixed)).source.value == "/native-resource-context";
      mixed-inactive-resource-keeps-context-lazy =
        declarations (
          (mixedApi.forRoster { inherit roster; }) {
            mixed = {
              hosts = [ "lumi" ];
              files = _: throw "inactive mixed branch";
              native = _: throw "inactive native branch";
            };
          }
        ) == [ ];
      extension-and-builtin-collisions-share-furnish =
        fails
          (furnish.compile {
            declarations = collide;
            executors = [ executor ];
            provider = furnish.core.offProvider;
          }).manifestData;
      legacy-canonical-mixes-fail = fails (legacy {
        furnish.links = [ ];
        links = [ ];
      });
    };
  failing = builtins.attrNames (lib.filterAttrs (_: value: !value) tests);
in
{
  inherit tests failing;
  ok =
    if failing == [ ] then
      true
    else
      throw "public declaration tests failed: ${lib.concatStringsSep ", " failing}";
}
