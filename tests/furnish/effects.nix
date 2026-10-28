{
  lib,
  axiom,
  krisis,
  retainedPath ? builtins.toFile "furnish-effects-source" "retained",
  furnish ? import ../../src/furnish {
    inherit lib axiom krisis;
    resolve = throw "furnish effects forced the user resolver";
    resolveSystem = throw "furnish effects forced the system resolver";
  },
}:
let
  poison = throw "furnish effects forced opaque data";
  declaration = {
    label = "resource";
    filesystemNamespace = "host";
    authority = {
      scope = "user";
      identity = "alice";
    };
    managedRoot = "/srv/alice";
    destination = ".config/resource";
    representation = "symlink";
    source = {
      kind = "opaque";
      value = {
        token = poison;
      };
    };
    generator = poison;
  };
  executor = {
    identity = "test/selected";
    priority = 1;
    protocolVersion = 1;
    enabled = true;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize =
      value:
      builtins.trace "resource-effects materialize" {
        target = {
          kind = "retained";
          path = retainedPath;
        };
        cleanupStrategy = "exact-symlink-target";
        selfHealStrategy = "exact-symlink-target";
        recovery = value.source.value;
      };
  };
  compile =
    overrides:
    furnish.compile (
      {
        declarations = [ declaration ];
        executors = [ executor ];
        provider = furnish.core.offProvider;
      }
      // overrides
    );
  compiled = compile { raw.secret = poison; };
  empty = compile {
    declarations = [ ];
    executors = poison;
    ctx = poison;
    provider = poison;
  };
  index = furnish.core.buildHostIndex {
    declarations = [ declaration ];
    principals = [
      {
        inherit (declaration) authority;
        ctx = poison;
      }
    ];
    provider = furnish.core.offProvider;
  };
  externalExecutor =
    path:
    executor
    // {
      materialize = _: {
        target = {
          kind = "external";
          inherit path;
        };
        cleanupStrategy = "exact-symlink-target";
        selfHealStrategy = "exact-symlink-target";
      };
    };
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  tests = {
    "test furnish protected preparation and artifact transport" = {
      expr =
        (builtins.head compiled.manifestData).target.path == retainedPath
        && builtins.hasContext compiled.manifestJson
        && compiled.manifestPath == null
        && builtins.attrNames compiled.raw == [ "secret" ];
      expected = true;
    };
    "test furnish empty keeps provider context and executors opaque" = {
      expr = empty.manifestData;
      expected = [ ];
    };
    "test furnish host index keeps source and context opaque" = {
      expr = builtins.attrNames index;
      expected = [ "host:/srv/alice/.config/resource" ];
    };
    "test furnish shape diagnostics keep payload opaque" = {
      expr = furnish.core.shapeDiagnostics declaration;
      expected = [ ];
    };
    "test furnish invalid shapes suppress provider and executors" = {
      expr =
        fails
          (compile {
            declarations = [ (declaration // { managedRoot = false; }) ];
            executors = poison;
            provider = poison;
          }).manifestData;
      expected = true;
    };
    "test furnish external rejects context and unnormalized paths" = {
      expr =
        builtins.all
          (
            path:
            fails
              (compile {
                executors = [ (externalExecutor path) ];
              }).manifestData
          )
          [
            retainedPath
            "/"
            "/outside/../target"
            "/outside//target"
          ];
      expected = true;
    };
    "test furnish absent external target does not read the filesystem" = {
      expr =
        (builtins.head
          (compile { executors = [ (externalExecutor "/absent/resource-effects-target") ]; }).manifestData
        ).target;
      expected = {
        kind = "external";
        path = "/absent/resource-effects-target";
      };
    };
    "test furnish equal content and policy do not excuse collisions" = {
      expr =
        fails
          (compile {
            declarations = [
              declaration
              (
                declaration
                // {
                  label = "duplicate";
                  onConflict = "runtime-wins";
                }
              )
            ];
            executors = poison;
          }).manifestData;
      expected = true;
    };
  };
in
{
  inherit tests;
  callbackProbe = {
    first = (builtins.head compiled.manifestData).target.path;
    second = (builtins.head compiled.manifestData).target.path;
  };
  exceptions = {
    provider =
      (compile { provider.selectApplicable = _: _: throw "resource effects provider exception"; })
      .manifestData;
    materializer =
      (compile {
        executors = [
          (
            executor
            // {
              materialize = _: throw "resource effects materializer exception";
            }
          )
        ];
      }).manifestData;
  };
}
