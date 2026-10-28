{
  lib,
  axiom,
  krisis,
}:
let
  outputs = import ../../src/declarations/outputs.nix { inherit lib axiom krisis; };
  targets = import ../../src/lexicon/target.nix { inherit lib axiom krisis; };
  inherit (krisis) effects;
  poison = throw "output boundary forced opaque data";
  args = output: {
    inherit output;
    definition.outputs = [
      "homeManager"
      "resources"
    ];
    scope = "user";
    resourceIntent = true;
    path = [ "example" ];
    annotationNames = [
      "hosts"
      "metadata"
    ];
    requested = [
      "homeManager"
      "resources"
    ];
  };
  locations = result: map (diagnostic: diagnostic.primary.label) result.diagnostics;
  codes = result: map (diagnostic: diagnostic.code) result.diagnostics;
  finite = {
    homeManager = [
      {
        module = {
          enabled = true;
        };
        origin = [
          "original"
          3
        ];
      }
    ];
    resources = [
      {
        kind = "file";
        value = {
          source = "opaque-source";
        };
        origin = [
          "original"
          7
        ];
      }
    ];
  };
  opaque = outputs.validate (args {
    homeManager = [
      {
        module = {
          opaque = poison;
        };
        origin = [
          "original"
          3
        ];
      }
    ];
    resources = [
      {
        kind = "file";
        value = {
          source = poison;
        };
        prepared = poison;
        origin = [
          "original"
          7
        ];
      }
    ];
  });
  guarded = outputs.validate (
    (args {
      nixos = [ poison ];
      resources = [ poison ];
    })
    // {
      definition.outputs = [ "homeManager" ];
      requested = [ "homeManager" ];
      resourceIntent = false;
    }
  );
  malformed = outputs.validate {
    output = {
      unknown = poison;
    };
    path = [ "example" ];
    definition = poison;
    scope = poison;
    requested = poison;
    resourceIntent = poison;
    annotationNames = poison;
  };
  independent = outputs.validate (args {
    homeManager = [
      {
        module = 1;
        origin = [ ];
      }
      {
        module = { };
        origin = [ (-1) ];
      }
    ];
    resources = [
      {
        kind = "unknown";
        origin = [ false ];
        value = 1;
      }
    ];
  });
  annotations = outputs.validate (args {
    resources = [
      {
        kind = "file";
        value = {
          metadata = poison;
          hosts = poison;
        };
        origin = [ ];
      }
    ];
  });
  target = {
    host = {
      name = "host";
      system = "system";
    };
    user.name = "user";
  };
  invalidTarget = targets.validate {
    host = {
      name = false;
      system = 1;
    };
    user = {
      name = false;
      home = "relative";
    };
  };
  outerTarget = targets.validate {
    host = {
      name = poison;
      system = poison;
    };
    unknown = poison;
  };
  tests = {
    "test empty output does not demand unrelated guards" = {
      expr =
        (outputs.validate {
          output = { };
          path = [ "example" ];
          definition = poison;
          scope = poison;
          requested = poison;
          resourceIntent = poison;
          annotationNames = poison;
        }).value;
      expected = {
        nixos = [ ];
        homeManager = [ ];
        resources = [ ];
      };
    };
    "test omitted contributions default to empty lists" = {
      expr = (outputs.validate (args { })).value;
      expected = {
        nixos = [ ];
        homeManager = [ ];
        resources = [ ];
      };
    };
    "test public result and native computation have equal projections" = {
      expr = (outputs.validate (args finite)).value;
      expected = effects.finishComputation (_: poison) (outputs.validateComputation (args finite));
    };
    "test native and resource envelopes keep payloads opaque" = {
      expr =
        opaque.diagnostics == [ ]
        &&
          (builtins.head opaque.value.homeManager).origin == [
            "original"
            3
          ]
        && builtins.attrNames (builtins.head opaque.value.homeManager).module == [ "opaque" ]
        && builtins.attrNames (builtins.head opaque.value.resources).value == [ "source" ]
        &&
          (builtins.head opaque.value.resources).origin == [
            "original"
            7
          ];
      expected = true;
    };
    "test native functions remain ordinary opaque modules" = {
      expr =
        builtins.isFunction
          (builtins.head
            (outputs.validate (args {
              homeManager = [
                {
                  module = _: poison;
                  origin = [ ];
                }
              ];
            })).value.homeManager
          ).module;
      expected = true;
    };
    "test output guard accumulates before item validation" = {
      expr =
        codes guarded == [
          "lexicon/output-projection"
          "lexicon/output-projection"
          "lexicon/undeclared-output"
          "lexicon/undeclared-output"
          "lexicon/output-scope"
          "lexicon/resource-intent"
        ]
        && !(guarded ? value);
      expected = true;
    };
    "test malformed envelope suppresses dependent controls" = {
      expr =
        codes malformed == [ "lexicon/unknown-field" ] && locations malformed == [ "$.example.unknown" ];
      expected = true;
    };
    "test contribution items accumulate in group and authored order" = {
      expr = locations independent;
      expected = [
        "$.example.homeManager[0].module"
        "$.example.homeManager[1].origin"
        "$.example.resources[0].kind"
        "$.example.resources[0].origin"
        "$.example.resources[0].value"
      ];
    };
    "test returned annotation values are never inspected" = {
      expr =
        locations annotations == [
          "$.example.resources[0].value.hosts"
          "$.example.resources[0].value.metadata"
        ]
        &&
          codes annotations == [
            "lexicon/output-annotation"
            "lexicon/output-annotation"
          ];
      expected = true;
    };
    "test target public result and computation have equal projections" = {
      expr = (targets.validate target).value;
      expected = effects.finishComputation (_: poison) (targets.validateComputation target);
    };
    "test target normalization preserves defaults" = {
      expr = targets.normalize target;
      expected = {
        host = {
          name = "host";
          system = "system";
          id = "system/host";
        };
        user = {
          name = "user";
          home = "/home/user";
        };
      };
    };
    "test target normalization preserves explicit identities" = {
      expr = targets.normalize {
        host = target.host // {
          id = "custom-host";
        };
        user = {
          name = "user";
          home = "/srv/user";
        };
      };
      expected = {
        host = target.host // {
          id = "custom-host";
        };
        user = {
          name = "user";
          home = "/srv/user";
        };
      };
    };
    "test host and user target failures accumulate in existing order" = {
      expr = locations invalidTarget;
      expected = [
        "$.target.host.name"
        "$.target.host.system"
        "$.target.user.home"
        "$.target.user.name"
      ];
    };
    "test outer target failure suppresses identity fields" = {
      expr = locations outerTarget == [ "$.target.unknown" ] && !(outerTarget ? value);
      expected = true;
    };
  };
in
{
  inherit tests;
  callbackExceptions = {
    nativeModule = outputs.validate (args {
      homeManager = [
        {
          module = throw "output native module exception";
          origin = [ ];
        }
      ];
    });
    resourceValue = outputs.validate (args {
      resources = [
        {
          kind = "file";
          value = throw "output resource value exception";
          origin = [ ];
        }
      ];
    });
    targetName = targets.validate {
      host = {
        name = throw "output target name exception";
        system = "system";
      };
    };
  };
}
