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
  # these suites borrow this file's public fixtures, so they are imported here
  links = import ./links.nix {
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
  };
  contextualTheme = import ./contextual-theme.nix {
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
  };
  tests = {
    "test den extra roster shape fails" = {
      expr = api.forDen {
        inherit den;
        selectionRoster = [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/roster-shape\\] \\$\\.selectionRoster: selection roster must be a record";
    };
    "test nonboolean resource intent has diagnostic" = {
      expr =
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
          { invalid = { }; };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/resource-intent-shape\\] \\$\\.invalid: resource intent must be a boolean";
    };
    "test target host diagnostic has field path" = {
      expr = locations (
        (import ../../src/lexicon/target.nix { inherit lib axiom krisis; }).validate {
          host = target.host // {
            name = 1;
          };
        }
      );
      expected = [ "$.target.host.name" ];
    };
    "test target user diagnostic has field path" = {
      expr = locations (
        (import ../../src/lexicon/target.nix { inherit lib axiom krisis; }).validate (
          target
          // {
            user = target.user // {
              home = "relative";
            };
          }
        )
      );
      expected = [ "$.target.user.home" ];
    };
    "test system predicates see null user and callbacks keep user" = {
      expr = (hostWhen owned).services.hostWhen;
      expected = "alice";
    };
    "test den system predicates see null user" = {
      expr = (hostWhen denPlain).services.hostWhen;
      expected = "alice";
    };
    "test advanced system selection and merge see null user" = {
      expr = (hostWhen systemObserver).services.hostWhen;
      expected = "alice";
    };
    "test advanced system predicates see null user" = {
      expr = (hostWhen advanced).services.hostWhen;
      expected = "alice";
    };
    "test direct system callback keeps bound user" = {
      expr =
        ((direct { nixos = callback: [ { value.services.callbackUser = callback.user.name; } ]; }).nixos
          args
        ).imports;
      expected = [ { services.callbackUser = "alice"; } ];
    };
    "test native role argument remains owned by module system" = {
      expr =
        (lib.evalModules {
          modules = [
            roleNative.homeManager
            { _module.args.role = "native-role-argument"; }
          ];
          specialArgs = removeAttrs args [ "config" ];
        }).config.nativeRole;
      expected = "native-role-argument";
    };
    "test inherited theme source retains field origin" = {
      expr = locations (owners.validatePlan (builtins.head inheritedTemplate));
      expected = [ "$.theme.source" ];
    };
    "test overridden theme source retains field origin" = {
      expr = locations (owners.validatePlan (builtins.head overriddenTemplate));
      expected = [ "$.theme.renderers.noctalia.source" ];
    };
    "test mixed wrong output is rejected" = {
      expr = wrongProjection.homeManager args;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/output-projection\\] \\$\\.bad\\.resources: contribution is outside the requested native bridge projection";
    };
    "test empty legacy imports are inert" = {
      expr = oldDirect { imports = [ ]; };
      expected = { };
    };
    "test empty canonical theme is inert without user" = {
      expr = hostTarget {
        theme = {
          id = "empty";
          templates = [ ];
        };
      };
      expected = { };
    };
    "test empty legacy theme is inert without user" = {
      expr = (lexicon.lib.programDirect { target.host = target.host; }) {
        theme = {
          id = "empty";
          templates = [ ];
        };
      };
      expected = { };
    };
    "test empty theme mixed fields fail" = {
      expr = hostTarget {
        theme = {
          id = "empty";
          templates = [ ];
          source = throw "must not read mixed source";
        };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/theme-mixed-syntax\\] \\$\\.theme: theme cannot mix templates with inline fields";
    };
    "test legacy direct native functions and paths remain modules" = {
      expr = evaluatedDirect;
      expected = {
        path = true;
        callback = "hello";
      };
    };
    "test legacy owned mixed value fails even when inactive" = {
      expr =
        (legacy {
          nixos = [
            {
              hosts = [ "lumi" ];
              value.answer = 1;
              services.answer = true;
            }
          ];
        }).nixos
          args;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unit-mixed-value\\] \\$\\.nixos: a unit cannot mix value with inline native config";
    };
    "test legacy owned malformed users remain errors" = {
      expr = (legacy { nixos = [ { users.users.alice.isNormalUser = true; } ]; }).nixos args;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/annotation-shape\\] \\$\\.nixos\\[0\\]\\.users: ownerships: 'users' must be a list of names; got set\\. a reserved ";
    };
    "test canonical direct native function and path values work" = {
      expr =
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
        }).config.nativeResult;
      expected = evaluatedDirect;
    };
    "test recursive wrapper only cycle fails" = {
      expr =
        (lexicon.lib.lexicon.configure {
          extensions = [ (recursiveExtension (d: d.recursive (self: d.forOutputs [ "resources" ] self))) ];
        }).forTarget
          { inherit target; }
          { };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/recursive-body\\] \\$\\.blocks\\.tree\\.node: recursive body must consume authored data before a reference";
    };
    "test malformed recursive binder fails" = {
      expr =
        (lexicon.lib.lexicon.configure {
          extensions = [
            (recursiveExtension (_: {
              kind = "recursive";
              body = "bad";
            }))
          ];
        }).forTarget
          { inherit target; }
          { };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/shape\\] \\$\\.blocks\\.tree\\.node\\.body: unexpected string";
    };
    "test recursive wrapper unknown field fails" = {
      expr =
        (lexicon.lib.lexicon.configure {
          extensions = [ (recursiveExtension (d: (d.recursive (_: d.record { })) // { unknown = true; })) ];
        }).forTarget
          { inherit target; }
          { };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.blocks\\.tree\\.node\\.unknown: unregistered field unknown";
    };
    "test reference outside binder fails" = {
      expr =
        (lexicon.lib.lexicon.configure {
          extensions = [
            (recursiveExtension (_: {
              kind = "reference";
              name = "outside";
            }))
          ];
        }).forTarget
          { inherit target; }
          { };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/recursive-reference\\] \\$\\.blocks\\.tree\\.node: reference is outside its recursive binder";
    };
    "test builtin file diagnostic keeps authored index" = {
      expr = locations (validate {
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
      });
      expected = [ "$.furnish.files[1].destination" ];
    };
    "test builtin file missing source has field path" = {
      expr = locations (validate {
        furnish.files = [ { destination = "missing"; } ];
      });
      expected = [ "$.furnish.files[0].source" ];
    };
    "test builtin directory diagnostic has field path" = {
      expr = locations (validate {
        furnish.directories = [
          {
            inherit source;
            destination = 1;
          }
        ];
      });
      expected = [ "$.furnish.directories[0].destination" ];
    };
    "test builtin override diagnostic keeps authored index" = {
      expr = locations (validate {
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
      });
      expected = [ "$.furnish.directories[0].files[1].names" ];
    };
    "test theme id diagnostic has field path" = {
      expr = locations (validate {
        theme = {
          id = 1;
          renderers.noctalia = {
            inherit source;
            output = "x";
          };
        };
      });
      expected = [ "$.theme.id" ];
    };
    "test selected theme diagnostic keeps original template and renderer" = {
      expr = locations (owners.validatePlan (builtins.head selectedTemplate));
      expected = [ "$.theme.templates[1].renderers.noctalia.source" ];
    };
    "test shared renderers retain their origin" = {
      expr =
        builtins.length sharedTemplate == 2
        && builtins.all (
          plan:
          plan.origin == [
            "theme"
            "renderers"
            "noctalia"
          ]
        ) sharedTemplate;
      expected = true;
    };
    "test all inactive renderers produce no plans" = {
      expr = declarations (owned {
        theme = {
          id = "inactive";
          renderers.noctalia = {
            roles = [ "laptop" ];
            source = throw "inactive renderer";
            output = "x";
          };
        };
      });
      expected = [ ];
    };
    "test authored empty renderers remain invalid" = {
      expr = declarations (owned {
        theme = {
          id = "empty";
          renderers = { };
        };
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[program/theme-renderers-empty\\] \\$\\.theme: renderers must select at least one renderer";
    };
    "test reserved axis context fails at binding" = {
      expr = (lexicon.lib.lexicon.configure { extensions = [ reservedAxis ]; }).forRoster {
        inherit roster;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/context-collision\\] \\$\\.config: axis context key collides with a bridge argument";
    };
    "test den extra roster cannot replace base" = {
      expr = api.forDen {
        inherit den;
        selectionRoster.hosts = [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/roster-override\\] \\$\\.selectionRoster\\.hosts: selection roster cannot override a base field";
    };
    "test factory is plain function" = {
      expr = builtins.isFunction owned && builtins.isFunction direct;
      expected = true;
    };
    "test all registered resources share selection" = {
      expr =
        builtins.length selectedEntries == 4
        && builtins.all (
          entry:
          entry.authority.identity == "alice"
          && entry.managedRoot == "/srv/alice"
          && entry.filesystemNamespace == target.host.id
        ) selectedEntries;
      expected = true;
    };
    "test canonical and legacy manifests match" = {
      expr = declarations (canonicalPlain canonicalSpec);
      expected = declarations (legacy legacySpec);
    };
    "test canonical direct and roster match" = {
      expr = declarations ((lexicon.lib.lexicon.forTarget { inherit target; }) canonicalSpec);
      expected = declarations (canonicalPlain canonicalSpec);
    };
    "test den binding keeps principal" = {
      expr = (builtins.head (declarations (denPlain canonicalSpec))).authority.identity;
      expected = "alice";
    };
    "test advanced binding uses configured vocabulary" = {
      expr = builtins.length (
        declarations (advanced {
          roles = [ "desktop" ];
          bookmarks.entries = [ link ];
        })
      );
      expected = 1;
    };
    "test missing context fails" = {
      expr = declarations (noContext {
        bookmarks = {
          roles = [ "desktop" ];
          entries = [ link ];
        };
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit '\\$\\.bookmarks': axis 'role' is narrowed on by claim \\{ set = \\[ \"desktop\" \\]; tag = \"include\"; \\} but the bu";
    };
    "test unknown context key fails when demanded" = {
      expr = declarations (invalidContext {
        furnish = {
          roles = [ "desktop" ];
          links = [ link ];
        };
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.selectionContext\\.host: unregistered field host";
    };
    "test nonrecord context fails when demanded" = {
      expr = declarations (nonRecordContext {
        roles = [ "desktop" ];
        furnish.links = [ link ];
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/record\\] \\$\\.selectionContext: expected an attribute set";
    };
    "test unclaimed extra context stays lazy" = {
      expr = builtins.length (declarations (unusedContext canonicalSpec));
      expected = 1;
    };
    "test inactive custom callback stays lazy" = {
      expr = declarations (owned {
        roles = [ "laptop" ];
        bookmarks.entries = _: throw "inactive callback";
      });
      expected = [ ];
    };
    "test block and entry narrowing" = {
      expr = declarations (owned {
        furnish = {
          roles = [ "laptop" ];
          links = [ (link // { source = throw "inactive source"; }) ];
        };
      });
      expected = [ ];
    };
    "test metadata validates on builtins" = {
      expr = declarations (owned {
        furnish = {
          metadata.tags = 1;
          links = [ link ];
        };
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[bookmarks/tags\\] \\$\\.furnish\\.metadata\\.tags: tags must be strings";
    };
    "test direct rejects custom static claim" = {
      expr = direct {
        furnish.links = [ (link // { roles = [ "desktop" ]; }) ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.links\\[0\\]\\.roles: direct binding rejects ownership annotations";
    };
    "test direct rejects custom dynamic claim" = {
      expr = declarations (direct {
        furnish.links = _: [ (link // { roles = [ "desktop" ]; }) ];
      });
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.furnish\\.links\\[0\\]\\.roles: direct binding rejects ownership annotations";
    };
    "test host only native remains lazy" = {
      expr = builtins.attrNames (hostTarget {
        package = p: p.hello;
      });
      expected = [ "homeManager" ];
    };
    "test empty collection callback needs user" = {
      expr = hostTarget {
        furnish.links = _: [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/resource-user\\] \\$\\.target\\.user: resource-producing declarations require a concrete user target";
    };
    "test empty static collection is inert" = {
      expr = hostTarget { furnish.links = [ ]; };
      expected = { };
    };
    "test recursive system unit selects and merges" = {
      expr = (recursiveSystem.nixos args).services.deep.enabled;
      expected = true;
    };
    "test inactive recursive callback and native stay lazy" = {
      expr = inactiveSystem.nixos args;
      expected = { };
    };
    "test static forbidden deep descendant fails before filter" = {
      expr =
        (owned {
          nixos = [
            {
              hosts = [ "lumi" ];
              children = [ ((nested 4 { }) // { roles = [ "desktop" ]; }) ];
            }
          ];
        }).nixos
          args;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/annotation-scope\\] \\$\\.nixos\\[0\\]\\.children\\[0\\]\\.roles: ownerships: a system-scope unit sets 'roles' = \\[\"desk";
    };
    "test dynamic recursive descendants work" = {
      expr =
        (
          (owned { nixos = [ { children = _: [ (nested 3 { services.dynamic.enabled = true; }) ]; } ]; })
          .nixos
          args
        ).services.dynamic.enabled;
      expected = true;
    };
    "test direct recursive custom claim fails" = {
      expr = direct {
        nixos = [ { children = [ ((nested 4 { }) // { roles = [ "desktop" ]; }) ]; } ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.nixos\\[0\\]\\.children\\[0\\]\\.roles: direct binding rejects ownership annotations";
    };
    "test scalar unit conflicts remain errors" = {
      expr =
        (owned {
          nixos = [
            { value.answer = 1; }
            { value.answer = 2; }
          ];
        }).nixos
          args;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/merge/conflict\\] conflict at answer: co-owners \"unlabeled unit \\{ answer \\}\" set differing values";
    };
    "test native priorities remain native" = {
      expr =
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
        }).config.answer;
      expected = 2;
    };
    "test native ownership looking fields stay opaque" = {
      expr =
        ((direct { nixos = [ { value.users.users.alice.isNormalUser = true; } ]; }).nixos args).imports;
      expected = [ { users.users.alice.isNormalUser = true; } ];
    };
    "test mixed home does not force resource callback" = {
      expr = mixedHome.test;
      expected = "home-argument";
    };
    "test mixed resource gets system config" = {
      expr = (builtins.head (declarations mixed)).source.value;
      expected = "/native-resource-context";
    };
    "test mixed inactive resource keeps context lazy" = {
      expr = declarations (
        (mixedApi.forRoster { inherit roster; }) {
          mixed = {
            hosts = [ "lumi" ];
            files = _: throw "inactive mixed branch";
            native = _: throw "inactive native branch";
          };
        }
      );
      expected = [ ];
    };
    "test extension and builtin collisions share furnish" = {
      expr =
        fails
          (furnish.compile {
            declarations = collide;
            executors = [ executor ];
            provider = furnish.core.offProvider;
          }).manifestData;
      expected = true;
    };
    "test legacy canonical mixes fail" = {
      expr = legacy {
        furnish.links = [ ];
        links = [ ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/legacy-mix\\] \\$: legacy and canonical declaration forms cannot be mixed";
    };
  };
in
{
  inherit tests links contextualTheme;
}
