{
  lib,
  axiom,
  krisis,
  registrationSource ? ../../src/declarations/definitions.nix,
  registration ? import registrationSource { inherit lib axiom krisis; },
}:
let
  inherit (registration) definitions;
  block = name: node: {
    inherit name node;
    scope = "user";
    outputs = [ "homeManager" ];
    lower = _: throw "registration forced lowering";
  };
  extension = name: blocks: _: { inherit name blocks; };
  recursiveNode = definitions.recursive (
    self:
    definitions.record {
      fields.payload.default = throw "registration forced a field default";
      children.descendants = definitions.collection { item = self; };
      prepare = _: throw "registration forced preparation";
    }
  );
  configured = registration.configure {
    blocks = [ (block "builtin" (definitions.record { })) ];
    extensions = [
      (extension "first" [ (block "recursive" recursiveNode) ])
      (extension "second" [ (block "last" (definitions.record { })) ])
    ];
  };
  follow =
    depth: node:
    if depth == 0 then node.kind else follow (depth - 1) node.children.descendants.item.target;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  malformed = args: fails (registration.configure args);
  recursiveBlock = node: { blocks = [ (block "recursive" node) ]; };
  probeExtension =
    { axiom, definitions, ... }:
    builtins.trace "registration extension" {
      name = "probe";
      metadata = [
        {
          name = "parsed";
          field.parse = value: builtins.trace "registration parse" (axiom.validation.success value);
        }
        {
          name = "normalized";
          field = {
            default = builtins.trace "registration default" "fallback";
            normalize = value: builtins.trace "registration normalize" value;
          };
        }
      ];
      blocks = [ (block "probe" (definitions.record { })) ];
    };
  probe = registration.configure { extensions = [ probeExtension ]; };
  parsed =
    (axiom.schema.compile {
      fields = probe.metadataFields;
      onRecord = _: throw "registration expected a record";
      onUnknown = _: _: throw "registration unexpected field";
    })
      { parsed = "authored"; };
  tests = {
    "test registrations preserve builtins and extension order" = {
      expr = map (entry: entry.name) configured.blocks.registrations;
      expected = [
        "builtin"
        "recursive"
        "last"
      ];
    };
    "test productive recursion keeps reference targets lazy" = {
      expr =
        configured.blocks.byKey.recursive.node.validated
        && follow 128 configured.blocks.byKey.recursive.node == "record";
      expected = true;
    };
    "test registered functions and payload defaults stay opaque" = {
      expr =
        builtins.isFunction configured.blocks.byKey.recursive.lower
        && builtins.isFunction configured.blocks.byKey.recursive.node.prepare
        && builtins.attrNames configured.blocks.byKey.recursive.node.fields.payload == [ "default" ];
      expected = true;
    };
    "test metadata retains external parse and default specifications" = {
      expr =
        parsed.diagnostics == [ ]
        && parsed.value.parsed == "authored"
        && parsed.value.normalized == "fallback";
      expected = true;
    };
    "test extension envelope rejects unknown fields" = {
      expr = malformed {
        extensions = [
          (_: {
            name = "unknown";
            typo = throw "unknown extension payload";
          })
        ];
      };
      expected = true;
    };
    "test extension list rejects nonfunctions" = {
      expr = malformed { extensions = [ 1 ]; };
      expected = true;
    };
    "test extension names collide before block registration" = {
      expr = malformed {
        extensions = [
          (extension "same" [ (block "first" (definitions.record { })) ])
          (extension "same" [ (block "second" (definitions.record { })) ])
        ];
      };
      expected = true;
    };
    "test malformed extension suppresses dependent block inspection" = {
      expr = malformed {
        extensions = [
          (_: {
            name = 1;
            blocks = [ (throw "registration inspected a rejected extension block") ];
          })
        ];
      };
      expected = true;
    };
    "test block and metadata collision registries remain active" = {
      expr =
        malformed {
          blocks = [
            (block "same" (definitions.record { }))
            (block "same" (definitions.record { }))
          ];
        }
        && malformed {
          extensions = [
            (_: {
              name = "metadata";
              metadata = [
                {
                  name = "same";
                  field = { };
                }
                {
                  name = "same";
                  field = { };
                }
              ];
            })
          ];
        };
      expected = true;
    };
    "test malformed blocks precede node compilation" = {
      expr = malformed {
        blocks = [
          (
            (block "bad" (
              definitions.record { fields.unused.validate = throw "registration compiled a rejected block node"; }
            ))
            // {
              scope = "invalid";
            }
          )
        ];
      };
      expected = true;
    };
    "test unproductive recursion is rejected" = {
      expr =
        malformed (recursiveBlock (definitions.recursive (self: self)))
        && malformed (
          recursiveBlock (
            definitions.recursive (self: definitions.forOutputs [ "homeManager" ] (definitions.contextual self))
          )
        );
      expected = true;
    };
    "test recursive binder shape and vocabulary are checked" = {
      expr =
        malformed (recursiveBlock {
          kind = "recursive";
          body = 1;
        })
        && malformed (
          recursiveBlock (
            (definitions.recursive (_: definitions.record { })) // { extra = throw "unused recursive field"; }
          )
        );
      expected = true;
    };
    "test references cannot escape their binder" = {
      expr = malformed (recursiveBlock {
        kind = "reference";
        name = "outside";
      });
      expected = true;
    };
    "test node and field schema contracts remain checked" = {
      expr =
        malformed { blocks = [ (block "unknown" { kind = "unknown"; }) ]; }
        && malformed { blocks = [ (block "field" (definitions.record { fields.bad.validate = 1; })) ]; }
        && malformed {
          blocks = [
            (block "collision" (
              definitions.record {
                fields.child = { };
                children.child = definitions.record { };
              }
            ))
          ];
        };
      expected = true;
    };
  };
  diagnosticReporter = _: rec {
    fail =
      diagnostics:
      throw (
        builtins.toJSON (
          map (diagnostic: {
            inherit (diagnostic) code severity message;
            path = diagnostic.primary.label;
          }) diagnostics
        )
      );
    finish = krisis.effects.finish fail;
    checked = diagnostics: value: finish { inherit diagnostics value; };
  };
  captured = import registrationSource {
    inherit lib axiom;
    krisis = krisis // {
      effects = krisis.effects // {
        reporter = diagnosticReporter;
      };
    };
  };
in
{
  inherit tests;
  callbackProbe = {
    first = parsed.value;
    again = parsed.value;
    blockNames = probe.blocks.keys;
  };
  diagnosticCases = {
    extensions = captured.configure {
      extensions = [
        1
        false
      ];
    };
    metadata = captured.configure {
      extensions = [
        (_: {
          name = "metadata";
          metadata = [
            { field = { }; }
            {
              name = 1;
              field = { };
            }
          ];
        })
      ];
    };
    blocks = captured.configure {
      blocks = [
        { }
        { }
      ];
    };
    duplicates = captured.configure {
      extensions = [
        (extension "same" [ ])
        (extension "same" [ ])
      ];
    };
    rejectedExtension = captured.configure {
      extensions = [
        (_: {
          name = 1;
          blocks = [ (throw "registration inspected a rejected extension block") ];
        })
      ];
    };
    rejectedBlock = captured.configure {
      blocks = [
        (
          (block "bad" (
            definitions.record { fields.unused.validate = throw "registration compiled a rejected block node"; }
          ))
          // {
            scope = "invalid";
          }
        )
      ];
    };
  };
  exceptions = {
    extension = registration.configure {
      extensions = [ (_: throw "registration extension exception") ];
    };
    recursive = registration.configure (
      recursiveBlock (definitions.recursive (_: throw "registration recursive exception"))
    );
  };
}
