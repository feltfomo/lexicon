{
  lib,
  axiom,
  krisis,
}:
let
  compiler = import ../../src/declarations { inherit lib axiom krisis; };
  inherit (compiler) definitions;
  bookmarks = import ./fixtures/bookmarks.nix;
  environment = compiler.configure { extensions = [ bookmarks ]; };
  inherit (environment) ownerships;
  roster = ownerships.toRoster [
    (ownerships.define.host "khion")
    (ownerships.define.host "lumi")
    (ownerships.define.user "feltfomo" {
      hosts = [
        "khion"
        "lumi"
      ];
    })
    (ownerships.define.user "other" { hosts = [ "khion" ]; })
    (ownerships.define.role "desktop")
    (ownerships.define.role "laptop")
  ];
  context = {
    host.name = "khion";
    user.name = "feltfomo";
    role.name = "desktop";
  };
  compile =
    declaration:
    ((environment.bind { inherit roster; }).prepare declaration).compile {
      inherit context;
      scope = "user";
    };
  throws = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  entry = {
    source = "/external/book";
    destination = ".bookmarks/book";
  };
  declaration.bookmarks.entries = [ entry ];
  three = compile {
    hosts = [
      "khion"
      "lumi"
    ];
    bookmarks = {
      roles = [
        "desktop"
        "laptop"
      ];
      entries = [
        (
          entry
          // {
            hosts = [ "lumi" ];
            source = throw "inactive source";
          }
        )
        (entry // { metadata.tags = [ "selected" ]; })
        (
          entry
          // {
            exceptRoles = [ "desktop" ];
            source = throw "excluded source";
          }
        )
      ];
    };
  };
  extensionWith = blocks: _: {
    name = "extra";
    inherit blocks;
  };
  captureNode = definitions.record {
    fields.marker = { };
    children = {
      optional = definitions.record { fields.payload = { }; };
      entries = definitions.collection {
        contextual = true;
        item = definitions.record { fields.payload = { }; };
      };
      named = definitions.recordMap {
        key = name: name != "bad";
        item = definitions.record { fields.payload = { }; };
      };
      native = definitions.native {
        owner = "test-native";
        validate = builtins.isAttrs;
      };
      scalar = definitions.value {
        validate = builtins.isString;
        onInvalid = _: _: {
          severity = "error";
          code = "string";
          message = "expected string";
        };
      };
    };
    prepare = { structure, origins }: {
      reserved = builtins.concatMap (entry: entry.payload.names or [ ]) (
        if builtins.isList (structure.entries or [ ]) then structure.entries or [ ] else [ ]
      );
      path = origins.self;
    };
  };
  captureBlock = {
    name = "capture";
    scope = "user";
    outputs = [ "homeManager" ];
    node = captureNode;
    lower =
      {
        value,
        metadata,
        origins,
        prepared,
        ...
      }:
      {
        homeManager = [
          {
            origin = origins.self;
            module = {
              inherit
                value
                metadata
                origins
                prepared
                ;
            };
          }
        ];
      };
  };
  captureEnvironment = compiler.configure {
    extensions = [
      bookmarks
      (extensionWith [ captureBlock ])
    ];
  };
  capture =
    value:
    let
      result = ((captureEnvironment.bind { inherit roster; }).prepare { capture = value; }).compile {
        inherit context;
        scope = "user";
      };
    in
    (builtins.head result.homeManager).module;
  sampleCapture = capture {
    marker = "hello";
    metadata.tags = [ "root" ];
    optional = {
      hosts = [ "lumi" ];
      payload = throw "inactive optional";
    };
    entries = [
      {
        hosts = [ "lumi" ];
        payload.names = [ "reserved" ];
      }
      {
        payload.names = [ "selected" ];
        metadata.tags = [ "child" ];
      }
    ];
    named = {
      z = {
        hosts = [ "lumi" ];
        payload = throw "inactive map";
      };
      a.payload = "first";
    };
    native = {
      hosts = "native field";
      roles = throw "native opaque body";
    };
    scalar = "value";
  };
  direct = (environment.bind { inherit roster; }).prepare declaration;
  malformed = args: throws (compiler.configure args).blocks.keys;
  alter = changes: _: {
    name = "alter";
    blocks = [ (captureBlock // changes) ];
  };
  outputWith = output: compiler.configure { extensions = [ (alter { lower = _: output; }) ]; };
  evaluateOutput =
    output:
    (((outputWith output).bind { inherit roster; }).prepare { capture = { }; }).compile {
      inherit context;
      scope = "user";
    };
  selected = compile declaration;
  tests = {
    "test external block lowers through registry" = {
      expr = (builtins.head selected.resources).value;
      expected = entry;
    };
    "test custom and host annotations narrow" = {
      expr = builtins.length three.resources;
      expected = 1;
    };
    "test authored index survives filter" = {
      expr = (builtins.head three.resources).origin;
      expected = [
        "bookmarks"
        "entries"
        1
      ];
    };
    "test root ancestry constrains block" = {
      expr =
        (compile {
          hosts = [ "lumi" ];
          bookmarks.entries = _: throw "inactive callback";
        }).resources;
      expected = [ ];
    };
    "test block ancestry constrains callback" = {
      expr =
        (compile {
          bookmarks = {
            roles = [ "laptop" ];
            entries = _: throw "inactive block callback";
          };
        }).resources;
      expected = [ ];
    };
    "test empty collection is retained" = {
      expr = (compile { bookmarks.entries = [ ]; }).resources;
      expected = [ ];
    };
    "test optional record is omitted" = {
      expr = !(sampleCapture.value ? optional);
      expected = true;
    };
    "test record map filters and retains name" = {
      expr = builtins.attrNames sampleCapture.value.named;
      expected = [ "a" ];
    };
    "test original map origin" = {
      expr = sampleCapture.origins.children.named.a.self;
      expected = [
        "capture"
        "named"
        "a"
      ];
    };
    "test original list origin" = {
      expr = (builtins.head sampleCapture.origins.children.entries).self;
      expected = [
        "capture"
        "entries"
        1
      ];
    };
    "test metadata does not inherit" = {
      expr =
        sampleCapture.metadata.self.tags == [ "root" ]
        && (builtins.head sampleCapture.metadata.children.entries).self.tags == [ "child" ]
        && sampleCapture.metadata.children.named.a.self == { };
      expected = true;
    };
    "test annotations are stripped" = {
      expr = !(sampleCapture.value ? metadata) && !(builtins.head sampleCapture.value.entries ? metadata);
      expected = true;
    };
    "test native record is opaque" = {
      expr = sampleCapture.value.native.hosts;
      expected = "native field";
    };
    "test value node validates" = {
      expr =
        sampleCapture.value.scalar == "value"
        && throws (capture {
          scalar = 42;
        });
      expected = true;
    };
    "test structural reservations include inactive" = {
      expr = sampleCapture.prepared.self.reserved;
      expected = [
        "reserved"
        "selected"
      ];
    };
    "test preparation keeps authored path" = {
      expr = sampleCapture.prepared.self.path;
      expected = [ "capture" ];
    };
    "test inactive preparation is lazy" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter { node = definitions.record { prepare = _: throw "inactive preparation"; }; })
            ];
          };
        in
        (((env.bind { inherit roster; }).prepare { capture.hosts = [ "lumi" ]; }).compile {
          inherit context;
          scope = "user";
        }).homeManager == [ ];
      expected = true;
    };
    "test callback result reenters selection" = {
      expr =
        builtins.length
          (compile {
            bookmarks.entries = _: [
              (entry // { roles = [ "laptop" ]; })
              entry
            ];
          }).resources;
      expected = 1;
    };
    "test callback receives same context" = {
      expr =
        (builtins.head
          (compile { bookmarks.entries = args: [ (entry // { destination = args.role.name; }) ]; }).resources
        ).value.destination;
      expected = "desktop";
    };
    "test callback result shape fails" = {
      expr = compile {
        bookmarks.entries = _: { };
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/collection-shape\\] \\$\\.bookmarks\\.entries: expected a list";
    };
    "test callback result unknown field fails" = {
      expr = compile {
        bookmarks.entries = _: [ (entry // { typo = true; }) ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.bookmarks\\.entries\\[0\\]\\.typo: unregistered field typo";
    };
    "test callback result claim shape fails" = {
      expr = compile {
        bookmarks.entries = _: [ (entry // { roles = "desktop"; }) ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/annotation-shape\\] \\$\\.bookmarks\\.entries\\[0\\]\\.roles: ownerships: 'roles' must be a list of names; got stri";
    };
    "test missing custom context fails" = {
      expr =
        ((environment.bind { inherit roster; }).prepare {
          bookmarks = {
            roles = [ "desktop" ];
            entries = [ entry ];
          };
        }).compile
          {
            scope = "user";
            context = removeAttrs context [ "role" ];
          };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit '\\$\\.bookmarks': axis 'role' is narrowed on by claim \\{ set = \\[ \"desktop\" \\]; tag = \"include\"; \\} but the bu";
    };
    "test inactive callback context stays lazy" = {
      expr =
        (compile {
          hosts = [ "lumi" ];
          bookmarks.entries = _: throw "inactive callback";
        }).resources;
      expected = [ ];
    };
    "test unsupported scope fails" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "system";
                outputs = [ "nixos" ];
                lower = _: { };
              })
            ];
          };
        in
        throws (
          ((env.bind { inherit roster; }).prepare { capture.roles = [ "desktop" ]; }).compile {
            inherit context;
            scope = "system";
          }
        );
      expected = true;
    };
    "test declaration user claim projects for system" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                scope = "system";
                outputs = [ "nixos" ];
                lower = { origins, ... }: {
                  nixos = [
                    {
                      module = { };
                      origin = origins.self;
                    }
                  ];
                };
              })
            ];
          };
        in
        builtins.length
          (
            ((env.bind { inherit roster; }).prepare {
              users = [ "other" ];
              capture = { };
            }).compile
            {
              inherit context;
              scope = "system";
            }
          ).nixos == 1;
      expected = true;
    };
    "test direct rejects custom root claim" = {
      expr =
        ((environment.bind { direct = true; }).prepare {
          roles = [ "desktop" ];
          bookmarks.entries = [ ];
        }).compile
          {
            inherit context;
            scope = "user";
          };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.roles: direct binding rejects ownership annotations";
    };
    "test direct rejects custom entry claim" = {
      expr =
        ((environment.bind { direct = true; }).prepare {
          bookmarks.entries = [ (entry // { roles = [ "desktop" ]; }) ];
        }).compile
          {
            inherit context;
            scope = "user";
          };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.bookmarks\\.entries\\[0\\]\\.roles: direct binding rejects ownership annotations";
    };
    "test direct rejects callback custom claim" = {
      expr =
        ((environment.bind { direct = true; }).prepare {
          bookmarks.entries = _: [ (entry // { roles = [ "desktop" ]; }) ];
        }).compile
          {
            inherit context;
            scope = "user";
          };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.bookmarks\\.entries\\[0\\]\\.roles: direct binding rejects ownership annotations";
    };
    "test direct allows metadata" = {
      expr =
        builtins.length
          (
            ((environment.bind { direct = true; }).prepare {
              bookmarks.entries = [ (entry // { metadata.tags = [ ]; }) ];
            }).compile
            {
              inherit context;
              scope = "user";
            }
          ).resources;
      expected = 1;
    };
    "test direct host only native remains valid" = {
      expr =
        builtins.length
          (((captureEnvironment.bind { direct = true; }).prepare { capture = { }; }).compile {
            context = { inherit (context) host; };
            scope = "user";
          }).homeManager;
      expected = 1;
    };
    "test direct resource needs user even empty callback" = {
      expr = ((environment.bind { direct = true; }).prepare { bookmarks.entries = _: [ ]; }).compile {
        context = { inherit (context) host; };
        scope = "user";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/resource-user\\] \\$\\.bookmarks: resource-producing declarations require a concrete user target";
    };
    "test selected domain validation fails" = {
      expr = compile {
        bookmarks.entries = [ (entry // { source = 1; }) ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[bookmarks/string\\] \\$\\.bookmarks\\.entries\\[0\\]\\.source: bookmark field must be a string";
    };
    "test unknown root field fails" = {
      expr = compile {
        typo = throw "unknown field payload";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.typo: unregistered field typo";
    };
    "test unknown inactive entry field fails" = {
      expr = compile {
        bookmarks.entries = [
          (
            entry
            // {
              hosts = [ "lumi" ];
              typo = throw "unknown inactive payload";
            }
          )
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.bookmarks\\.entries\\[0\\]\\.typo: unregistered field typo";
    };
    "test invalid map key fails" = {
      expr = capture {
        named.bad.payload = true;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/record-map-key\\] \\$\\.capture\\.named\\.bad: invalid record map key";
    };
    "test malformed metadata fails" = {
      expr = compile {
        bookmarks.metadata.tags = "oops";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[bookmarks/tags\\] \\$\\.bookmarks\\.metadata\\.tags: tags must be strings";
    };
    "test unregistered metadata fails" = {
      expr = compile {
        bookmarks.metadata.typo = throw "unknown metadata";
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.bookmarks\\.metadata\\.typo: unregistered field typo";
    };
    "test registration rejects malformed extension" = {
      expr = malformed {
        extensions = [
          (_: {
            name = "x";
            typo = true;
          })
        ];
      };
      expected = true;
    };
    "test registration rejects duplicate extension" = {
      expr = malformed {
        extensions = [
          bookmarks
          bookmarks
        ];
      };
      expected = true;
    };
    "test registration rejects duplicate block" = {
      expr = malformed {
        extensions = [
          (extensionWith [
            captureBlock
            captureBlock
          ])
        ];
      };
      expected = true;
    };
    "test registration rejects block claim collision" = {
      expr = malformed {
        extensions = [ (alter { name = "hosts"; }) ];
      };
      expected = true;
    };
    "test registration rejects record claim collision" = {
      expr = malformed {
        extensions = [ (alter { node = definitions.record { fields.hosts = { }; }; }) ];
      };
      expected = true;
    };
    "test registration rejects domain child collision" = {
      expr = malformed {
        extensions = [
          (alter {
            node = definitions.record {
              fields.entries = { };
              children.entries = definitions.collection { item = definitions.record { }; };
            };
          })
        ];
      };
      expected = true;
    };
    "test registration rejects unknown definition field" = {
      expr = malformed {
        extensions = [ (alter { typo = true; }) ];
      };
      expected = true;
    };
    "test registration rejects invalid node" = {
      expr = malformed {
        extensions = [ (alter { node.kind = "unknown"; }) ];
      };
      expected = true;
    };
    "test registration rejects invalid field schema" = {
      expr = malformed {
        extensions = [ (alter { node = definitions.record { fields.example.validate = 1; }; }) ];
      };
      expected = true;
    };
    "test registration rejects duplicate metadata" = {
      expr = malformed {
        extensions = [
          bookmarks
          (_: {
            name = "other";
            metadata = [
              {
                name = "tags";
                field = { };
              }
            ];
          })
        ];
      };
      expected = true;
    };
    "test registration rejects malformed before lower" = {
      expr = malformed {
        extensions = [
          (alter {
            scope = "bad";
            lower = _: throw "lower ran before registration";
          })
        ];
      };
      expected = true;
    };
    "test output envelope is closed" = {
      expr = evaluateOutput {
        typo = true;
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.capture\\.typo: unregistered field typo";
    };
    "test output scope is checked" = {
      expr = evaluateOutput {
        nixos = [
          {
            module = { };
            origin = [ ];
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/undeclared-output\\] \\$\\.capture\\.nixos: definition did not declare this contribution";
    };
    "test output kind must be declared" = {
      expr = evaluateOutput {
        resources = [
          {
            kind = "external-link";
            value = entry;
            origin = [ ];
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/undeclared-output\\] \\$\\.capture\\.resources: definition did not declare this contribution";
    };
    "test output origin is structured" = {
      expr = evaluateOutput {
        homeManager = [
          {
            module = { };
            origin = [ (-1) ];
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/shape\\] \\$\\.capture\\.homeManager\\[0\\]\\.origin: unexpected list";
    };
    "test native contribution envelope is closed" = {
      expr = evaluateOutput {
        homeManager = [
          {
            module = { };
            origin = [ ];
            typo = true;
          }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.capture\\.homeManager\\[0\\]\\.typo: unregistered field typo";
    };
    "test invalid selected child fails even when lower ignores value" = {
      expr =
        let
          env = compiler.configure { extensions = [ (alter { lower = _: { }; }) ]; };
        in
        throws (
          ((env.bind { inherit roster; }).prepare { capture.scalar = 42; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test invalid selected callback fails even when lower ignores value" = {
      expr =
        let
          env = compiler.configure { extensions = [ (alter { lower = _: { }; }) ]; };
        in
        throws (
          ((env.bind { inherit roster; }).prepare { capture.entries = _: { }; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test split lower and callback receive scope" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                scope = "split";
                outputs = [
                  "homeManager"
                  "nixos"
                ];
                lower =
                  {
                    value,
                    context,
                    origins,
                    ...
                  }:
                  {
                    ${if context.scope == "user" then "homeManager" else "nixos"} = [
                      {
                        module = value;
                        origin = origins.self;
                      }
                    ];
                  };
              })
            ];
          };
          prepared = (env.bind { inherit roster; }).prepare {
            capture.entries = args: [ { payload = args.scope; } ];
          };
          user = prepared.compile {
            inherit context;
            scope = "user";
          };
          system = prepared.compile {
            inherit context;
            scope = "system";
          };
        in
        (builtins.head (builtins.head user.homeManager).module.entries).payload == "user"
        && (builtins.head (builtins.head system.nixos).module.entries).payload == "system";
      expected = true;
    };
    "test resource intent cannot lie" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                resourceIntent = _: false;
                outputs = [ "resources" ];
                lower = _: {
                  resources = [
                    {
                      kind = "external-link";
                      value = entry;
                      origin = [ ];
                    }
                  ];
                };
              })
            ];
          };
        in
        throws (
          ((env.bind { direct = true; }).prepare { capture = { }; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test inactive resource intent is lazy" = {
      expr =
        let
          env = compiler.configure {
            extensions = [ (alter { resourceIntent = _: throw "inactive intent"; }) ];
          };
        in
        (((env.bind { inherit roster; }).prepare { capture.hosts = [ "lumi" ]; }).compile {
          inherit context;
          scope = "user";
        }).homeManager == [ ];
      expected = true;
    };
    "test registration rejects malformed metadata schema" = {
      expr = malformed {
        extensions = [
          (_: {
            name = "bad";
            metadata = [
              {
                name = "tags";
                field.validate = 1;
              }
            ];
          })
        ];
      };
      expected = true;
    };
    "test registration rejects duplicate author key" = {
      expr = malformed {
        extensions = [
          bookmarks
          ({ definitions, ... }: {
            name = "clash";
            ownership = [
              (definitions.mkPredicateDescriptor {
                name = "duplicate";
                authorKey = "hosts";
                order = 99;
                allowedScopes = [ "user" ];
              })
            ];
          })
        ];
      };
      expected = true;
    };
    "test registration rejects reserved author key" = {
      expr = malformed {
        extensions = [
          ({ definitions, ... }: {
            name = "clash";
            ownership = [
              (definitions.mkPredicateDescriptor {
                name = "duplicate";
                authorKey = "value";
                order = 99;
                allowedScopes = [ "user" ];
              })
            ];
          })
        ];
      };
      expected = true;
    };
    "test registration rejects unknown relation axis" = {
      expr = malformed {
        extensions = [
          (_: {
            name = "bad";
            relations = [
              {
                name = "bad-relation";
                leftAxis = "host";
                rightAxis = "missing";
                unknownFor = _: {
                  left = [ ];
                  right = [ ];
                };
                compatibleFor =
                  _: _: _:
                  true;
                reason = _: _: "bad relation";
              }
            ];
          })
        ];
      };
      expected = true;
    };
    "test resource output envelope is closed" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                outputs = [ "resources" ];
                lower = _: {
                  resources = [
                    {
                      kind = "external-link";
                      value = entry;
                      origin = [ ];
                      authority = "forbidden";
                    }
                  ];
                };
              })
            ];
          };
        in
        throws (
          ((env.bind { direct = true; }).prepare { capture = { }; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test split collection items keep explicit scope" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "split";
                outputs = [ "nixos" ];
                node = definitions.collection {
                  contextual = true;
                  item = definitions.record { };
                };
                lower = _: {
                  nixos = [
                    {
                      module = { };
                      origin = [ ];
                    }
                  ];
                };
              })
            ];
          };
          compile =
            value:
            ((env.bind { inherit roster; }).prepare {
              users = [ "other" ];
              capture = value;
            }).compile
              {
                inherit context;
                scope = "system";
              };
        in
        {
          unclaimed = builtins.length (compile [ { } ]).nixos;
          staticUser = throws (compile [ { users = [ "other" ]; } ]);
          staticRole = throws (compile [ { roles = [ "desktop" ]; } ]);
          contextualUser = throws (compile (_: [ { users = [ "other" ]; } ]));
          contextualRole = throws (compile (_: [ { roles = [ "desktop" ]; } ]));
        };
      expected = {
        unclaimed = 1;
        staticUser = true;
        staticRole = true;
        contextualUser = true;
        contextualRole = true;
      };
    };
    "test split record map items keep explicit scope" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "split";
                outputs = [ "nixos" ];
                node = definitions.recordMap {
                  key = _: true;
                  item = definitions.record { };
                };
                lower = _: {
                  nixos = [
                    {
                      module = { };
                      origin = [ ];
                    }
                  ];
                };
              })
            ];
          };
          compile =
            value:
            ((env.bind { inherit roster; }).prepare {
              users = [ "other" ];
              capture = value;
            }).compile
              {
                inherit context;
                scope = "system";
              };
        in
        builtins.length (compile { unit = { }; }).nixos == 1
        && throws (compile {
          unit.users = [ "other" ];
        })
        && throws (compile {
          unit.roles = [ "desktop" ];
        });
      expected = true;
    };
    "test direct rejects static claims in other scope" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "system";
                outputs = [ "nixos" ];
                lower = _: { };
              })
            ];
          };
        in
        throws (
          ((env.bind { direct = true; }).prepare { capture.roles = [ "desktop" ]; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test inactive static system claims still fail" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "split";
                outputs = [ "nixos" ];
                lower = _: { };
              })
            ];
          };
          compile =
            entry:
            ((env.bind { inherit roster; }).prepare {
              capture = {
                hosts = [ "lumi" ];
                entries = [ entry ];
              };
            }).compile
              {
                inherit context;
                scope = "system";
              };
        in
        throws (compile {
          users = [ "other" ];
          payload = throw "inactive payload";
        })
        && throws (compile {
          roles = [ "desktop" ];
          payload = throw "inactive payload";
        });
      expected = true;
    };
    "test inactive callback scope pass stays lazy" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                scope = "split";
                outputs = [ "nixos" ];
                lower = _: { };
              })
            ];
          };
        in
        (
          ((env.bind { inherit roster; }).prepare {
            capture = {
              hosts = [ "lumi" ];
              entries = _: throw "inactive callback";
            };
          }).compile
          {
            inherit context;
            scope = "system";
          }
        ).nixos == [ ];
      expected = true;
    };
    "test callback static scope check precedes item selection" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                scope = "split";
                outputs = [ "nixos" ];
                lower = _: { };
              })
            ];
          };
        in
        throws (
          ((env.bind { inherit roster; }).prepare {
            capture.entries = _: [
              {
                hosts = [ "lumi" ];
                roles = [ "desktop" ];
                payload = throw "inactive payload";
              }
            ];
          }).compile
            {
              inherit context;
              scope = "system";
            }
        );
      expected = true;
    };
    "test schema defaults remain lazy until selection" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              (alter {
                node = definitions.record {
                  fields.payload = {
                    default = throw "poisoned default";
                    validate = builtins.isString;
                    onInvalid = _: _: {
                      severity = "error";
                      code = "default";
                      message = "default rejected";
                    };
                  };
                };
                lower = _: { };
              })
            ];
          };
          inherit ((env.bind { inherit roster; })) prepare;
          compile =
            declaration:
            (prepare declaration).compile {
              inherit context;
              scope = "user";
            };
        in
        (compile { }).homeManager == [ ]
        && (compile { capture.hosts = [ "lumi" ]; }).homeManager == [ ]
        && throws (compile {
          capture = { };
        });
      expected = true;
    };
    "test sibling diagnostics keep authored order" = {
      expr =
        let
          result =
            ((environment.bind { inherit roster; }).prepare {
              bookmarks.entries = [
                {
                  source = 1;
                  destination = ".first";
                }
                {
                  source = false;
                  destination = ".second";
                }
              ];
            }).validate
              {
                inherit context;
                scope = "user";
              };
        in
        map (diagnostic: diagnostic.primary.label) result.diagnostics == [
          "$.bookmarks.entries[0].source"
          "$.bookmarks.entries[1].source"
        ];
      expected = true;
    };
    "test domain and metadata diagnostics accumulate" = {
      expr =
        let
          result =
            ((environment.bind { inherit roster; }).prepare {
              bookmarks.entries = [
                {
                  source = 1;
                  destination = ".first";
                  metadata.tags = false;
                }
              ];
            }).validate
              {
                inherit context;
                scope = "user";
              };
        in
        map (diagnostic: diagnostic.primary.label) result.diagnostics == [
          "$.bookmarks.entries[0].source"
          "$.bookmarks.entries[0].metadata.tags"
        ];
      expected = true;
    };
    "test structural sibling diagnostics accumulate" = {
      expr = (environment.bind { inherit roster; }).prepare {
        bookmarks.entries = [
          { typo = true; }
          { otherTypo = true; }
        ];
      };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.bookmarks\\.entries\\[0\\]\\.typo: unregistered field typo";
    };
    "test lower cannot reintroduce custom annotations" = {
      expr =
        let
          env = compiler.configure {
            extensions = [
              bookmarks
              (alter {
                outputs = [ "resources" ];
                lower = _: {
                  resources = [
                    {
                      kind = "external-link";
                      value = entry // {
                        roles = throw "output annotation payload";
                      };
                      origin = [ ];
                    }
                  ];
                };
              })
            ];
          };
        in
        throws (
          ((env.bind { inherit roster; }).prepare { capture = { }; }).compile {
            inherit context;
            scope = "user";
          }
        );
      expected = true;
    };
    "test value node diagnostic path is authored" = {
      expr =
        let
          result = ((captureEnvironment.bind { inherit roster; }).prepare { capture.scalar = 42; }).validate {
            inherit context;
            scope = "user";
          };
        in
        map (diagnostic: diagnostic.primary.label) result.diagnostics == [ "$.capture.scalar" ];
      expected = true;
    };
    "test advanced resolver vocabulary is shared" = {
      expr =
        let
          resolvers = ownerships.mkResolvers roster;
        in
        builtins.length
          (
            (
              (environment.bind {
                resolvers = {
                  inherit (resolvers) resolveSystem;
                  resolvePrepared = resolvers.prepared;
                };
              }).prepare
              {
                bookmarks = {
                  roles = [ "desktop" ];
                  entries = [ entry ];
                };
              }
            ).compile
            {
              inherit context;
              scope = "user";
            }
          ).resources == 1;
      expected = true;
    };
  };
in
{
  inherit tests;
}
