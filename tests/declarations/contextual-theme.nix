{
  lib,
  pkgs,
  lexicon,
  owned,
  direct,
  hostTarget,
  target,
  args,
  roster,
  declarations,
  fails,
  plans,
  validate,
  locations,
  owners,
  compiler,
}:
let
  theme = {
    id = "contextual";
    renderers.noctalia = {
      source = ../program/fixtures/sample-tree/safe-render.nix;
      output = ".config/contextual";
    };
  };
  callback =
    {
      pkgs,
      host,
      user,
      config,
      role,
      ...
    }:
    theme
    // {
      reload = "${pkgs.coreutils}/bin/true ${host.name} ${user.home} ${config.resourceOnly} ${role.name}";
    };
  contextual = (plans { theme = callback; }).resources;
  extension = { definitions, ... }: {
    name = "contextual-record";
    blocks = [
      {
        name = "contextualRecord";
        scope = "user";
        outputs = [
          "homeManager"
          "resources"
        ];
        node = definitions.record {
          children = {
            entry = definitions.forOutputs [ "resources" ] (
              definitions.contextual (
                definitions.record {
                  fields = {
                    source = { };
                    destination = { };
                  };
                }
              )
            );
            home = definitions.forOutputs [ "homeManager" ] (
              definitions.native {
                owner = "native-test";
                validate = builtins.isAttrs;
              }
            );
          };
        };
        lower =
          {
            value,
            origins,
            metadata,
            context,
            ...
          }:
          if context.output == "homeManager" then
            {
              homeManager = [
                {
                  module = value.home;
                  origin = origins.children.home;
                }
              ];
            }
          else
            {
              resources = lib.optional (value ? entry) {
                kind = "external-link";
                value = value.entry // {
                  provenance = builtins.concatStringsSep "/" metadata.children.entry.self.tags;
                };
                origin = origins.children.entry.self;
              };
            };
      }
    ];
  };
  extended = lexicon.lib.lexicon.configure {
    extensions = [
      (import ./fixtures/bookmarks.nix)
      extension
    ];
  };
  mixed = (extended.forTarget { inherit target; }) {
    contextualRecord = {
      entry = { config, ... }: {
        source = "/${config.resourceOnly}";
        destination = ".contextual-record";
        metadata.tags = [
          "record"
          "metadata"
        ];
      };
      home.home.test = "home-output";
    };
    theme = _: throw "resource theme invoked by Home Manager";
  };
  malformedDefinition =
    node:
    fails
      (compiler.configure {
        blocks = [
          {
            name = "bad";
            scope = "user";
            outputs = [ "resources" ];
            inherit node;
            lower = _: { };
          }
        ];
      }).blocks.keys;
  inherit (compiler) definitions;
in
{
  "test theme context receives native resource arguments" = {
    expr = (builtins.head contextual).value.entry.reload;
    expected = "${pkgs.coreutils}/bin/true khion /srv/alice native-resource-context desktop";
  };
  "test theme context public factory lowers" = {
    expr =
      declarations (owned {
        theme = callback;
      })
      # declaration lists hold derivations, so compare by output path rather than deep forcing
      == declarations (owned {
        theme = callback (args // { role.name = "desktop"; });
      });
    expected = true;
  };
  "test theme context direct factory lowers" = {
    expr =
      declarations (direct {
        theme = _: theme;
      })
      # declaration lists hold derivations, so compare by output path rather than deep forcing
      == declarations (direct {
        inherit theme;
      });
    expected = true;
  };
  "test theme context root ancestry skips invocation" = {
    expr = declarations (owned {
      hosts = [ "lumi" ];
      theme = _: throw "inactive theme";
    });
    expected = [ ];
  };
  "test theme context custom ancestry skips invocation" = {
    expr = declarations (owned {
      roles = [ "laptop" ];
      theme = _: throw "inactive theme";
    });
    expected = [ ];
  };
  "test theme context returned claims filter before payload" = {
    expr = declarations (owned {
      theme = _: {
        id = "inactive";
        roles = [ "laptop" ];
        source = throw "inactive payload";
      };
    });
    expected = [ ];
  };
  "test theme context returned renderer claims filter" = {
    expr = declarations (owned {
      theme =
        _:
        theme
        // {
          renderers.noctalia = {
            roles = [ "laptop" ];
            source = throw "inactive renderer";
          };
        };
    });
    expected = [ ];
  };
  "test theme context registered metadata is accepted" = {
    expr =
      (declarations (owned {
        theme =
          _:
          theme
          // {
            metadata.tags = [ "theme" ];
            renderers.noctalia = theme.renderers.noctalia // {
              metadata.tags = [ "renderer" ];
            };
          };
      }))
      # declaration lists hold derivations, so compare by output path rather than deep forcing
      == declarations (owned {
        inherit theme;
      });
    expected = true;
  };
  "test theme context direct rejects returned root claim" = {
    expr = declarations (direct {
      theme = _: theme // { roles = [ "desktop" ]; };
    });
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.theme\\.roles: direct binding rejects ownership annotations";
  };
  "test theme context direct rejects returned descendant claim" = {
    expr = declarations (direct {
      theme =
        _:
        theme
        // {
          renderers.noctalia = theme.renderers.noctalia // {
            hosts = [ "lumi" ];
          };
        };
    });
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/direct-annotation\\] \\$\\.theme\\.renderers\\.noctalia\\.hosts: direct binding rejects ownership annotations";
  };
  "test theme context empty result remains inert" = {
    expr = declarations (direct {
      theme = _: {
        id = "empty";
        templates = [ ];
      };
    });
    expected = [ ];
  };
  "test theme context host only rejects without invoking" = {
    expr = hostTarget {
      theme = _: throw "must not invoke callback";
    };
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/resource-user\\] \\$\\.target\\.user: resource-producing declarations require a concrete user target";
  };
  "test theme context wrong result has authored path" = {
    expr = locations (validate {
      theme = _: [ ];
    });
    expected = [ "$.theme" ];
  };
  "test theme context returned function is not invoked" = {
    expr = locations (validate {
      theme = _: _: throw "second invocation";
    });
    expected = [ "$.theme" ];
  };
  "test theme context unknown field has authored path" = {
    expr = locations (validate {
      theme = _: {
        id = "x";
        typo = throw "unknown payload";
      };
    });
    expected = [ "$.theme.typo" ];
  };
  "test theme context claim shape has authored path" = {
    expr = locations (validate {
      theme = _: {
        id = "x";
        hosts = false;
      };
    });
    expected = [ "$.theme.hosts" ];
  };
  "test theme context metadata shape has authored path" = {
    expr = locations (validate {
      theme = _: {
        id = "x";
        metadata.tags = false;
      };
    });
    expected = [ "$.theme.metadata.tags" ];
  };
  "test theme context id shape has authored path" = {
    expr = locations (validate {
      theme = _: { id = false; };
    });
    expected = [ "$.theme.id" ];
  };
  "test theme context filtering retains template index" = {
    expr =
      let
        result =
          (plans {
            theme = _: {
              id = "origin";
              templates = [
                {
                  roles = [ "laptop" ];
                  source = throw "inactive template";
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
      in
      locations (owners.validatePlan (builtins.head result))
      == [ "$.theme.templates[1].renderers.noctalia.source" ];
    expected = true;
  };
  "test theme context callback gets no internal merger" = {
    expr =
      (plans {
        theme =
          args:
          assert !(args ? mergeSystem);
          theme;
      }).resources != [ ];
    expected = true;
  };
  "test theme context home output does not invoke resource callback" = {
    expr = (mixed.homeManager args).imports;
    expected = [ { home.test = "home-output"; } ];
  };
  "test external contextual record gets system config and metadata" = {
    expr =
      let
        entry = builtins.head (
          declarations (
            (extended.forTarget { inherit target; }) {
              contextualRecord.entry = { config, ... }: {
                source = "/${config.resourceOnly}";
                destination = ".contextual-record";
                metadata.tags = [
                  "record"
                  "metadata"
                ];
              };
            }
          )
        );
      in
      entry.source.value == "/native-resource-context" && entry.provenance.source == "record/metadata";
    expected = true;
  };
  "test theme context native function field stays opaque" = {
    expr =
      builtins.isFunction
        (builtins.head
          (plans {
            theme = _: theme // { native.hosts = _: throw "opaque native function"; };
          }).resources
        ).value.entry.native.hosts;
    expected = true;
  };
  "test theme context unknown nested annotation retains index" = {
    expr = locations (validate {
      theme = _: {
        id = "unknown";
        templates = [ { metadata.typo = true; } ];
      };
    });
    expected = [ "$.theme.templates[0].metadata.typo" ];
  };
  "test callback direct scan includes unrequested descendants" = {
    expr =
      let
        environment = compiler.configure {
          extensions = [ (import ./fixtures/bookmarks.nix) ];
          blocks = [
            {
              name = "contextualScan";
              scope = "user";
              outputs = [ "resources" ];
              node = definitions.contextual (
                definitions.record {
                  children.hidden = definitions.forOutputs [ "homeManager" ] (definitions.record { });
                }
              );
              lower = _: { };
            }
          ];
        };
      in
      fails (
        ((environment.bind { direct = true; }).prepare {
          contextualScan = _: { hidden.roles = [ "desktop" ]; };
        }).compile
          {
            scope = "user";
            context = args;
            outputs = [ "resources" ];
          }
      );
    expected = true;
  };
  "test callback scope check precedes returned selection" = {
    expr =
      let
        environment = compiler.configure {
          extensions = [ (import ./fixtures/bookmarks.nix) ];
          blocks = [
            {
              name = "systemRecord";
              scope = "system";
              outputs = [ "nixos" ];
              node = definitions.contextual (definitions.record { });
              lower = _: { };
            }
          ];
        };
        result =
          ((environment.bind { inherit roster; }).prepare {
            systemRecord = _: {
              hosts = [ "lumi" ];
              roles = [ "desktop" ];
            };
          }).validate
            {
              scope = "system";
              context = args;
              outputs = [ "nixos" ];
            };
      in
      locations result == [ "$.systemRecord.roles" ];
    expected = true;
  };
  "test contextual wrapper rejects native boundary" = {
    expr = malformedDefinition (
      definitions.contextual (
        definitions.native {
          owner = "native";
          validate = _: true;
        }
      )
    );
    expected = true;
  };
  "test contextual wrapper rejects nested wrapper" = {
    expr = malformedDefinition (
      definitions.contextual (definitions.contextual (definitions.record { }))
    );
    expected = true;
  };
  "test contextual wrapper rejects unknown fields" = {
    expr = malformedDefinition ((definitions.contextual (definitions.record { })) // { typo = true; });
    expected = true;
  };
  "test contextual wrapper does not make recursion productive" = {
    expr = malformedDefinition (definitions.recursive (self: definitions.contextual self));
    expected = true;
  };
  "test contextual wrapper mixed output requires projection" = {
    expr =
      fails
        (compiler.configure {
          blocks = [
            {
              name = "bad";
              scope = "user";
              outputs = [
                "homeManager"
                "resources"
              ];
              node = definitions.contextual (definitions.record { });
              lower = _: { };
            }
          ];
        }).blocks.keys;
    expected = true;
  };
}
