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
  theme-context-receives-native-resource-arguments =
    (builtins.head contextual).value.entry.reload
    == "${pkgs.coreutils}/bin/true khion /srv/alice native-resource-context desktop";
  theme-context-public-factory-lowers =
    declarations (owned {
      theme = callback;
    }) == declarations (owned {
      theme = callback (args // { role.name = "desktop"; });
    });
  theme-context-direct-factory-lowers =
    declarations (direct {
      theme = _: theme;
    }) == declarations (direct {
      inherit theme;
    });
  theme-context-root-ancestry-skips-invocation =
    declarations (owned {
      hosts = [ "lumi" ];
      theme = _: throw "inactive theme";
    }) == [ ];
  theme-context-custom-ancestry-skips-invocation =
    declarations (owned {
      roles = [ "laptop" ];
      theme = _: throw "inactive theme";
    }) == [ ];
  theme-context-returned-claims-filter-before-payload =
    declarations (owned {
      theme = _: {
        id = "inactive";
        roles = [ "laptop" ];
        source = throw "inactive payload";
      };
    }) == [ ];
  theme-context-returned-renderer-claims-filter =
    declarations (owned {
      theme =
        _:
        theme
        // {
          renderers.noctalia = {
            roles = [ "laptop" ];
            source = throw "inactive renderer";
          };
        };
    }) == [ ];
  theme-context-registered-metadata-is-accepted =
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
    })) == declarations (owned {
      inherit theme;
    });
  theme-context-direct-rejects-returned-root-claim = fails (
    declarations (direct {
      theme = _: theme // { roles = [ "desktop" ]; };
    })
  );
  theme-context-direct-rejects-returned-descendant-claim = fails (
    declarations (direct {
      theme =
        _:
        theme
        // {
          renderers.noctalia = theme.renderers.noctalia // {
            hosts = [ "lumi" ];
          };
        };
    })
  );
  theme-context-empty-result-remains-inert =
    declarations (direct {
      theme = _: {
        id = "empty";
        templates = [ ];
      };
    }) == [ ];
  theme-context-host-only-rejects-without-invoking = fails (hostTarget {
    theme = _: throw "must not invoke callback";
  });
  theme-context-wrong-result-has-authored-path =
    locations (validate {
      theme = _: [ ];
    }) == [ "$.theme" ];
  theme-context-returned-function-is-not-invoked =
    locations (validate {
      theme = _: _: throw "second invocation";
    }) == [ "$.theme" ];
  theme-context-unknown-field-has-authored-path =
    locations (validate {
      theme = _: {
        id = "x";
        typo = throw "unknown payload";
      };
    }) == [ "$.theme.typo" ];
  theme-context-claim-shape-has-authored-path =
    locations (validate {
      theme = _: {
        id = "x";
        hosts = false;
      };
    }) == [ "$.theme.hosts" ];
  theme-context-metadata-shape-has-authored-path =
    locations (validate {
      theme = _: {
        id = "x";
        metadata.tags = false;
      };
    }) == [ "$.theme.metadata.tags" ];
  theme-context-id-shape-has-authored-path =
    locations (validate {
      theme = _: { id = false; };
    }) == [ "$.theme.id" ];
  theme-context-filtering-retains-template-index =
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
  theme-context-callback-gets-no-internal-merger =
    (plans {
      theme =
        args:
        assert !(args ? mergeSystem);
        theme;
    }).resources != [ ];
  theme-context-home-output-does-not-invoke-resource-callback =
    (mixed.homeManager args).imports == [ { home.test = "home-output"; } ];
  external-contextual-record-gets-system-config-and-metadata =
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
  theme-context-native-function-field-stays-opaque =
    builtins.isFunction
      (builtins.head
        (plans {
          theme = _: theme // { native.hosts = _: throw "opaque native function"; };
        }).resources
      ).value.entry.native.hosts;
  theme-context-unknown-nested-annotation-retains-index =
    locations (validate {
      theme = _: {
        id = "unknown";
        templates = [ { metadata.typo = true; } ];
      };
    }) == [ "$.theme.templates[0].metadata.typo" ];
  callback-direct-scan-includes-unrequested-descendants =
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
  callback-scope-check-precedes-returned-selection =
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
  contextual-wrapper-rejects-native-boundary = malformedDefinition (
    definitions.contextual (
      definitions.native {
        owner = "native";
        validate = _: true;
      }
    )
  );
  contextual-wrapper-rejects-nested-wrapper = malformedDefinition (
    definitions.contextual (definitions.contextual (definitions.record { }))
  );
  contextual-wrapper-rejects-unknown-fields = malformedDefinition (
    (definitions.contextual (definitions.record { })) // { typo = true; }
  );
  contextual-wrapper-does-not-make-recursion-productive = malformedDefinition (
    definitions.recursive (self: definitions.contextual self)
  );
  contextual-wrapper-mixed-output-requires-projection =
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
}
