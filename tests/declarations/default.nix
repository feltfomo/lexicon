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
  cases = {
    external-block-lowers-through-registry = (builtins.head selected.resources).value == entry;
    custom-and-host-annotations-narrow = builtins.length three.resources == 1;
    authored-index-survives-filter =
      (builtins.head three.resources).origin == [
        "bookmarks"
        "entries"
        1
      ];
    root-ancestry-constrains-block =
      (compile {
        hosts = [ "lumi" ];
        bookmarks.entries = _: throw "inactive callback";
      }).resources == [ ];
    block-ancestry-constrains-callback =
      (compile {
        bookmarks = {
          roles = [ "laptop" ];
          entries = _: throw "inactive block callback";
        };
      }).resources == [ ];
    empty-collection-is-retained = (compile { bookmarks.entries = [ ]; }).resources == [ ];
    optional-record-is-omitted = !(sampleCapture.value ? optional);
    record-map-filters-and-retains-name = builtins.attrNames sampleCapture.value.named == [ "a" ];
    original-map-origin =
      sampleCapture.origins.children.named.a.self == [
        "capture"
        "named"
        "a"
      ];
    original-list-origin =
      (builtins.head sampleCapture.origins.children.entries).self == [
        "capture"
        "entries"
        1
      ];
    metadata-does-not-inherit =
      sampleCapture.metadata.self.tags == [ "root" ]
      && (builtins.head sampleCapture.metadata.children.entries).self.tags == [ "child" ]
      && sampleCapture.metadata.children.named.a.self == { };
    annotations-are-stripped =
      !(sampleCapture.value ? metadata) && !(builtins.head sampleCapture.value.entries ? metadata);
    native-record-is-opaque = sampleCapture.value.native.hosts == "native field";
    value-node-validates =
      sampleCapture.value.scalar == "value"
      && throws (capture {
        scalar = 42;
      });
    structural-reservations-include-inactive =
      sampleCapture.prepared.self.reserved == [
        "reserved"
        "selected"
      ];
    preparation-keeps-authored-path = sampleCapture.prepared.self.path == [ "capture" ];
    inactive-preparation-is-lazy =
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
    callback-result-reenters-selection =
      builtins.length
        (compile {
          bookmarks.entries = _: [
            (entry // { roles = [ "laptop" ]; })
            entry
          ];
        }).resources == 1;
    callback-receives-same-context =
      (builtins.head
        (compile { bookmarks.entries = args: [ (entry // { destination = args.role.name; }) ]; }).resources
      ).value.destination == "desktop";
    callback-result-shape-fails = throws (compile {
      bookmarks.entries = _: { };
    });
    callback-result-unknown-field-fails = throws (compile {
      bookmarks.entries = _: [ (entry // { typo = true; }) ];
    });
    callback-result-claim-shape-fails = throws (compile {
      bookmarks.entries = _: [ (entry // { roles = "desktop"; }) ];
    });
    missing-custom-context-fails = throws (
      ((environment.bind { inherit roster; }).prepare {
        bookmarks = {
          roles = [ "desktop" ];
          entries = [ entry ];
        };
      }).compile
        {
          scope = "user";
          context = removeAttrs context [ "role" ];
        }
    );
    inactive-callback-context-stays-lazy =
      (compile {
        hosts = [ "lumi" ];
        bookmarks.entries = _: throw "inactive callback";
      }).resources == [ ];
    unsupported-scope-fails =
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
    declaration-user-claim-projects-for-system =
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
    direct-rejects-custom-root-claim = throws (
      ((environment.bind { direct = true; }).prepare {
        roles = [ "desktop" ];
        bookmarks.entries = [ ];
      }).compile
        {
          inherit context;
          scope = "user";
        }
    );
    direct-rejects-custom-entry-claim = throws (
      ((environment.bind { direct = true; }).prepare {
        bookmarks.entries = [ (entry // { roles = [ "desktop" ]; }) ];
      }).compile
        {
          inherit context;
          scope = "user";
        }
    );
    direct-rejects-callback-custom-claim = throws (
      ((environment.bind { direct = true; }).prepare {
        bookmarks.entries = _: [ (entry // { roles = [ "desktop" ]; }) ];
      }).compile
        {
          inherit context;
          scope = "user";
        }
    );
    direct-allows-metadata =
      builtins.length
        (
          ((environment.bind { direct = true; }).prepare {
            bookmarks.entries = [ (entry // { metadata.tags = [ ]; }) ];
          }).compile
          {
            inherit context;
            scope = "user";
          }
        ).resources == 1;
    direct-host-only-native-remains-valid =
      builtins.length
        (((captureEnvironment.bind { direct = true; }).prepare { capture = { }; }).compile {
          context = { inherit (context) host; };
          scope = "user";
        }).homeManager == 1;
    direct-resource-needs-user-even-empty-callback = throws (
      ((environment.bind { direct = true; }).prepare { bookmarks.entries = _: [ ]; }).compile {
        context = { inherit (context) host; };
        scope = "user";
      }
    );
    selected-domain-validation-fails = throws (compile {
      bookmarks.entries = [ (entry // { source = 1; }) ];
    });
    unknown-root-field-fails = throws (compile {
      typo = throw "unknown field payload";
    });
    unknown-inactive-entry-field-fails = throws (compile {
      bookmarks.entries = [
        (
          entry
          // {
            hosts = [ "lumi" ];
            typo = throw "unknown inactive payload";
          }
        )
      ];
    });
    invalid-map-key-fails = throws (capture {
      named.bad.payload = true;
    });
    malformed-metadata-fails = throws (compile {
      bookmarks.metadata.tags = "oops";
    });
    unregistered-metadata-fails = throws (compile {
      bookmarks.metadata.typo = throw "unknown metadata";
    });
    registration-rejects-malformed-extension = malformed {
      extensions = [
        (_: {
          name = "x";
          typo = true;
        })
      ];
    };
    registration-rejects-duplicate-extension = malformed {
      extensions = [
        bookmarks
        bookmarks
      ];
    };
    registration-rejects-duplicate-block = malformed {
      extensions = [
        (extensionWith [
          captureBlock
          captureBlock
        ])
      ];
    };
    registration-rejects-block-claim-collision = malformed {
      extensions = [ (alter { name = "hosts"; }) ];
    };
    registration-rejects-record-claim-collision = malformed {
      extensions = [ (alter { node = definitions.record { fields.hosts = { }; }; }) ];
    };
    registration-rejects-domain-child-collision = malformed {
      extensions = [
        (alter {
          node = definitions.record {
            fields.entries = { };
            children.entries = definitions.collection { item = definitions.record { }; };
          };
        })
      ];
    };
    registration-rejects-unknown-definition-field = malformed {
      extensions = [ (alter { typo = true; }) ];
    };
    registration-rejects-invalid-node = malformed {
      extensions = [ (alter { node.kind = "unknown"; }) ];
    };
    registration-rejects-invalid-field-schema = malformed {
      extensions = [ (alter { node = definitions.record { fields.example.validate = 1; }; }) ];
    };
    registration-rejects-duplicate-metadata = malformed {
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
    registration-rejects-malformed-before-lower = malformed {
      extensions = [
        (alter {
          scope = "bad";
          lower = _: throw "lower ran before registration";
        })
      ];
    };
    output-envelope-is-closed = throws (evaluateOutput {
      typo = true;
    });
    output-scope-is-checked = throws (evaluateOutput {
      nixos = [
        {
          module = { };
          origin = [ ];
        }
      ];
    });
    output-kind-must-be-declared = throws (evaluateOutput {
      resources = [
        {
          kind = "external-link";
          value = entry;
          origin = [ ];
        }
      ];
    });
    output-origin-is-structured = throws (evaluateOutput {
      homeManager = [
        {
          module = { };
          origin = [ (-1) ];
        }
      ];
    });
    native-contribution-envelope-is-closed = throws (evaluateOutput {
      homeManager = [
        {
          module = { };
          origin = [ ];
          typo = true;
        }
      ];
    });
    invalid-selected-child-fails-even-when-lower-ignores-value =
      let
        env = compiler.configure { extensions = [ (alter { lower = _: { }; }) ]; };
      in
      throws (
        ((env.bind { inherit roster; }).prepare { capture.scalar = 42; }).compile {
          inherit context;
          scope = "user";
        }
      );
    invalid-selected-callback-fails-even-when-lower-ignores-value =
      let
        env = compiler.configure { extensions = [ (alter { lower = _: { }; }) ]; };
      in
      throws (
        ((env.bind { inherit roster; }).prepare { capture.entries = _: { }; }).compile {
          inherit context;
          scope = "user";
        }
      );
    split-lower-and-callback-receive-scope =
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
    resource-intent-cannot-lie =
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
    inactive-resource-intent-is-lazy =
      let
        env = compiler.configure {
          extensions = [ (alter { resourceIntent = _: throw "inactive intent"; }) ];
        };
      in
      (((env.bind { inherit roster; }).prepare { capture.hosts = [ "lumi" ]; }).compile {
        inherit context;
        scope = "user";
      }).homeManager == [ ];
    registration-rejects-malformed-metadata-schema = malformed {
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
    registration-rejects-duplicate-author-key = malformed {
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
    registration-rejects-reserved-author-key = malformed {
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
    registration-rejects-unknown-relation-axis = malformed {
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
    resource-output-envelope-is-closed =
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
    split-collection-items-keep-explicit-scope =
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
      builtins.length (compile [ { } ]).nixos == 1
      && throws (compile [ { users = [ "other" ]; } ])
      && throws (compile [ { roles = [ "desktop" ]; } ])
      && throws (compile (_: [ { users = [ "other" ]; } ]))
      && throws (compile (_: [ { roles = [ "desktop" ]; } ]));
    split-record-map-items-keep-explicit-scope =
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
    direct-rejects-static-claims-in-other-scope =
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
    inactive-static-system-claims-still-fail =
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
    inactive-callback-scope-pass-stays-lazy =
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
    callback-static-scope-check-precedes-item-selection =
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
    schema-defaults-remain-lazy-until-selection =
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
    sibling-diagnostics-keep-authored-order =
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
    domain-and-metadata-diagnostics-accumulate =
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
    structural-sibling-diagnostics-accumulate = throws (
      (environment.bind { inherit roster; }).prepare {
        bookmarks.entries = [
          { typo = true; }
          { otherTypo = true; }
        ];
      }
    );
    lower-cannot-reintroduce-custom-annotations =
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
    value-node-diagnostic-path-is-authored =
      let
        result = ((captureEnvironment.bind { inherit roster; }).prepare { capture.scalar = 42; }).validate {
          inherit context;
          scope = "user";
        };
      in
      map (diagnostic: diagnostic.primary.label) result.diagnostics == [ "$.capture.scalar" ];
    advanced-resolver-vocabulary-is-shared =
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
  };
  failing = builtins.attrNames (lib.filterAttrs (_: pass: !pass) cases);
  ok =
    if failing == [ ] then
      true
    else
      throw "declaration tests failed ${lib.concatStringsSep ", " failing}";
in
{
  inherit cases ok;
}
