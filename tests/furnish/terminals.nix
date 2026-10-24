{
  lib,
  axiom,
  lexicon,
  krisisSource,
  source ? ../..,
}:
let
  dependencies =
    override:
    import (source + "/src/dependencies.nix") {
      inherit lib axiom krisisSource;
      krisis = override;
    };
  original = (dependencies null).krisis;
  report = original.mkReporter {
    formatHeader = count: "program: ${toString count} declaration error(s)";
    formatDiagnostic = diagnostic: "  - " + original.renderPlain diagnostic;
  };
  declaration = {
    label = "terminal";
    filesystemNamespace = "host";
    authority = {
      scope = "user";
      identity = "alice";
    };
    managedRoot = "/srv/alice";
    destination = ".config/terminal";
    representation = "symlink";
    source = {
      kind = "opaque";
      value = throw "terminal source forced";
    };
  };
  artifact = {
    target = {
      kind = "external";
      path = "/external/terminal";
    };
    cleanupStrategy = "exact-symlink-target";
    selfHealStrategy = "exact-symlink-target";
  };
  executor = {
    identity = "terminal/executor";
    priority = 0;
    protocolVersion = 1;
    enabled = true;
    capabilities = [
      "lifecycle-baseline"
      "symlink"
    ];
    materialize = _: artifact;
  };
  trace = method: value: builtins.trace "terminal ${method}" value;
  recovering = _: {
    finish = _: trace "finish" (throw "unused reporter finish");
    fail =
      diagnostics:
      trace "fail" (
        if lib.hasPrefix "artifact-validation/" (builtins.head diagnostics).code then
          artifact
        else if lib.hasPrefix "executor-validation/" (builtins.head diagnostics).code then
          {
            registrations = [ executor ];
            ordered = [ executor ];
          }
        else if lib.hasPrefix "collision-detection/" (builtins.head diagnostics).code then
          {
            byKey.recovered-index = {
              recovered = true;
            };
          }
        else
          [ declaration ]
      );
    failOne =
      diagnostic:
      let
        recovery =
          {
            "capability-selection/no-capable-executor" = executor;
            "executor-validation/materialize-type" = _: artifact;
            "artifact-validation/external-target" = {
              recovered = "external";
            };
          }
          .${diagnostic.code};
      in
      trace "failOne" recovery;
    render = _: "unused render";
    renderOne = _: "unused renderOne";
    checked = _: _: trace "checked" (throw "unused reporter checked");
  };
  publicFurnish =
    mkReporter:
    lexicon.lib.furnish {
      krisis = { inherit mkReporter; };
      resolve = throw "terminal resolver forced";
      resolveSystem = throw "terminal system resolver forced";
    };
  furnish = publicFurnish recovering;
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
  entry = overrides: builtins.head (compile overrides).manifestData;
  shapeBad = declaration // {
    managedRoot = false;
  };
  themeWith =
    mkReporter:
    (import (source + "/src/lexicon/resources.nix") {
      inherit lib axiom;
      inherit (dependencies { inherit mkReporter; }) krisis;
    }).theme;
  theme = themeWith (_: report);
  normalize =
    renderer: blockId: native:
    theme.normalizeEntry {
      inherit renderer blockId;
      entry = {
        source = throw "terminal theme source forced";
        placedAs = "palette.tmpl";
        output = ".config/${blockId}";
        inherit native;
      };
    };
  a = normalize "caelestia" "a" { };
  aOne = a // {
    registrationId = "one";
  };
  aTwo = a // {
    registrationId = "two";
  };
  z = normalize "caelestia" "z" { unsupported = true; };
  poison = normalize "caelestia" "z" (throw "later theme native forced");
  pkgs = {
    formats.toml = _: { generate = _: value: builtins.toJSON value; };
    writeShellScript = _: _: throw "terminal hook generation forced";
  };
  themeFiles = entries: theme.themeFiles entries pkgs;
  capture = diagnostics: {
    diagnostics = map (diagnostic: {
      inherit (diagnostic) code severity message;
      primary = diagnostic.primary or null;
    }) diagnostics;
    text = report.render diagnostics;
  };
  checkedReporter =
    _:
    report
    // {
      finish = _: trace "finish" (throw "unused theme finish");
      fail = _: trace "fail" (throw "unused theme fail");
      checked =
        diagnostics: fallback:
        trace "checked" [
          (
            (capture diagnostics)
            // {
              fallbackLength = builtins.length fallback;
            }
          )
        ];
    };
  checkedTheme = themeWith checkedReporter;
  destinations = map (file: file.dest);
  principal = {
    authority = {
      scope = "user";
      identity = "alice";
    };
    managedRoot = "/srv/alice";
  };
  matugenEntry =
    namespace: id: native:
    (normalize "dms" "block" native)
    // {
      registrationId = id;
      filesystemNamespace = namespace;
      inherit principal;
    };
  ma = matugenEntry "a" "duplicate" { };
  maOne = ma // {
    registrationId = "one";
  };
  maTwo = ma // {
    registrationId = "two";
  };
  mz = matugenEntry "z" "duplicate" { };
  mp = matugenEntry "z" (throw "later Matugen registration forced") { };
  matugen =
    mkReporter: entries:
    let
      deps = dependencies { inherit mkReporter; };
    in
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        (import (source + "/src/program/theme/matugen-runtime.nix") {
          inherit axiom;
          inherit (deps) krisis;
        })
        ({ lib, ... }: {
          options.lexicon.furnish.declarations = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          config.lexicon.theme.matugen.entries = entries;
        })
      ];
    }).config.lexicon.furnish.declarations;
  finishReporter =
    _:
    report
    // {
      finish = result: trace "finish" report.finish result;
      checked = _: _: trace "checked" (throw "unused Matugen checked");
    };
  recoveringFinish =
    _:
    report
    // {
      finish = _: trace "finish" "Matugen terminal recovery";
      checked = _: _: trace "checked" (throw "unused Matugen checked");
    };
in
{
  dispatch = {
    validShape = (furnish.core.validateShape declaration).label;
    validShapeSentinel =
      (
        (publicFurnish (
          args:
          (recovering args)
          // {
            finish = _: trace "finish" { sentinel = true; };
          }
        )).core.validateShape
        declaration
      ).label;
    executorRecovery = map (value: value.identity) (
      furnish.core.validateExecutors [ (executor // { priority = false; }) ]
    );
    indexRecovery = builtins.attrNames (
      furnish.core.buildHostIndex {
        declarations = [
          declaration
          declaration
        ];
        principals = [
          {
            inherit (declaration) authority;
            ctx = throw "terminal index context forced";
          }
        ];
        provider = furnish.core.offProvider;
      }
    );
    indexShapeRecovery = builtins.attrNames (
      furnish.core.buildHostIndex {
        declarations = [ shapeBad ];
        principals = [
          {
            inherit (declaration) authority;
            ctx = throw "terminal index context forced";
          }
        ];
        provider = furnish.core.offProvider;
      }
    );
    shapeRecovery = (furnish.core.validateShape shapeBad).label;
    compileShapeRecovery =
      (entry {
        declarations = [ shapeBad ];
        provider.selectApplicable = values: _: trace "provider" values;
      }).target.path;
    capabilityRecovery = (furnish.core.selectExecutor [ ] declaration).identity;
    materializerRecovery = (entry { executors = [ (executor // { materialize = 1; }) ]; }).target.path;
    artifactRecovery = (entry { executors = [ (executor // { materialize = _: { }; }) ]; }).target.path;
    externalRecovery = entry {
      executors = [
        (
          executor
          // {
            materialize =
              _:
              artifact
              // {
                target = {
                  kind = "external";
                  path = "/srv/alice/.config/terminal";
                };
              };
          }
        )
      ];
    };
  };
  groups = {
    themeWithin = checkedTheme.themeFiles [ aOne aOne aTwo aTwo ] pkgs;
    matugenWithin = map (value: value.destination) (
      matugen recoveringFinish [
        maOne
        maOne
        maTwo
        maTwo
      ]
    );
    themeRecovery = checkedTheme.themeFiles [ a a z ] pkgs;
    themeSuccessThenRecovery = map (file: file.dest or file.text) (
      checkedTheme.themeFiles [ a z ] pkgs
    );
    themeSuccess = destinations (checkedTheme.themeFiles [ a ] pkgs);
    matugenRecovery = map (value: value.destination) (
      matugen recoveringFinish [
        ma
        ma
        mz
        mz
      ]
    );
    matugenSuccess = map (value: value.destination) (
      matugen recoveringFinish [
        ma
        mz
      ]
    );
    matugenNativeOpaque = map (value: value.destination) (
      matugen recoveringFinish [
        ma
        (
          mz
          // {
            native = throw "later Matugen native forced";
          }
        )
      ]
    );
  };
  exceptions = {
    themeWithin = builtins.length (themeFiles [
      aOne
      aOne
      aTwo
      aTwo
    ]);
    matugenWithin = builtins.length (
      matugen finishReporter [
        maOne
        maOne
        maTwo
        maTwo
      ]
    );
    themeTwo = builtins.length (themeFiles [
      a
      a
      z
    ]);
    themePoison = builtins.length (themeFiles [
      a
      a
      poison
    ]);
    themeSuccessThenFailure = builtins.length (themeFiles [
      a
      z
    ]);
    matugenTwo = builtins.length (
      matugen finishReporter [
        ma
        ma
        mz
        mz
      ]
    );
    matugenPoison = builtins.length (
      matugen finishReporter [
        ma
        ma
        mp
      ]
    );
    matugenSuccessThenFailure = builtins.length (
      matugen finishReporter [
        ma
        mz
        mz
      ]
    );
    matugenNativeAfterDuplicate = map (value: builtins.fromJSON value.source.value) (
      matugen finishReporter [
        ma
        ma
        (
          mz
          // {
            native = throw "later Matugen native forced";
          }
        )
      ]
    );
    themeSuccessPoison = builtins.length (themeFiles [
      a
      poison
    ]);
  };
}
