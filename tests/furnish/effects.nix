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
  cases = {
    furnish-protected-preparation-and-artifact-transport =
      (builtins.head compiled.manifestData).target.path == retainedPath
      && builtins.hasContext compiled.manifestJson
      && compiled.manifestPath == null
      && builtins.attrNames compiled.raw == [ "secret" ];
    furnish-empty-keeps-provider-context-and-executors-opaque = empty.manifestData == [ ];
    furnish-host-index-keeps-source-and-context-opaque =
      builtins.attrNames index == [ "host:/srv/alice/.config/resource" ];
    furnish-shape-diagnostics-keep-payload-opaque = furnish.core.shapeDiagnostics declaration == [ ];
    furnish-invalid-shapes-suppress-provider-and-executors =
      fails
        (compile {
          declarations = [ (declaration // { managedRoot = false; }) ];
          executors = poison;
          provider = poison;
        }).manifestData;
    furnish-external-rejects-context-and-unnormalized-paths =
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
    furnish-absent-external-target-does-not-read-the-filesystem =
      (builtins.head
        (compile { executors = [ (externalExecutor "/absent/resource-effects-target") ]; }).manifestData
      ).target == {
        kind = "external";
        path = "/absent/resource-effects-target";
      };
    furnish-equal-content-and-policy-do-not-excuse-collisions =
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
  };
in
{
  inherit cases;
  ok = builtins.all (value: value) (builtins.attrValues cases);
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
