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
  cells = {
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
  };

  duplicate = label: id: {
    code = "program/theme-registration-duplicate";
    message = "has duplicate registration id ${id}";
    primary.label = label;
    severity = "error";
  };
  unsupported = {
    code = "program/theme-native-unsupported";
    message = "cannot use native registration fields: z";
    primary.label = "theme.caelestia.z";
    severity = "error";
  };
  line = diagnostic: "\n  - [${diagnostic.code}] ${diagnostic.primary.label}: ${diagnostic.message}";
  checkedGroup = diagnostics: {
    inherit diagnostics;
    fallbackLength = 0;
    text = "program: ${toString (builtins.length diagnostics)} declaration error(s)${lib.concatMapStrings line diagnostics}";
  };
  matugenFile = ".config/matugen/config.toml";
  themeDestinations = [
    ".config/caelestia/templates/a-palette.tmpl"
    ".config/caelestia/theme-hooks/a"
  ];

  # a terminal's whole text, so a reporter that adds or drops a line fails
  terminal = name: lines: {
    expr = cells.exceptions.${name};
    expectedError.type = "ThrownError";
    expectedError.msg = "^${lib.escapeRegex "program: ${toString (builtins.length lines)} declaration error(s)${lib.concatMapStrings (text: "\n  - ${text}") lines}"}$";
  };
  themeDuplicate =
    id: "[program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id ${id}";
  matugenDuplicate =
    id: owner:
    "[program/theme-registration-duplicate] theme.dms: has duplicate registration id ${id} for ${owner} (alice)";
  themeUnsupported = "[program/theme-native-unsupported] theme.caelestia.z: cannot use native registration fields: z";
in
# which reporter method ran, how often and in which order is checked from the
# same cells by the events flake check. unused methods throw, so a value here
# also shows no other method's result was demanded
cells
// {
  tests = {
    "test a valid shape reaches no reporter" = {
      expr = cells.dispatch.validShape;
      expected = "terminal";
    };
    "test a valid shape ignores a sentinel finish" = {
      expr = cells.dispatch.validShapeSentinel;
      expected = "terminal";
    };
    "test an invalid executor recovers through fail" = {
      expr = cells.dispatch.executorRecovery;
      expected = [ "terminal/executor" ];
    };
    "test a host index collision recovers through fail" = {
      expr = cells.dispatch.indexRecovery;
      expected = [ "recovered-index" ];
    };
    "test a host index shape error recovers through fail" = {
      expr = cells.dispatch.indexShapeRecovery;
      expected = [ "host:/srv/alice/.config/terminal" ];
    };
    "test a shape error recovers through fail" = {
      expr = cells.dispatch.shapeRecovery;
      expected = "terminal";
    };
    "test a compile shape error recovers before the provider" = {
      expr = cells.dispatch.compileShapeRecovery;
      expected = "/external/terminal";
    };
    "test a missing capability recovers through failOne" = {
      expr = cells.dispatch.capabilityRecovery;
      expected = "terminal/executor";
    };
    "test an invalid materializer recovers through failOne" = {
      expr = cells.dispatch.materializerRecovery;
      expected = "/external/terminal";
    };
    "test an invalid artifact recovers through fail" = {
      expr = cells.dispatch.artifactRecovery;
      expected = "/external/terminal";
    };
    "test a managed external target recovers through failOne" = {
      expr = cells.dispatch.externalRecovery;
      expected.recovered = "external";
    };

    "test duplicates within one theme group report together" = {
      expr = cells.groups.themeWithin;
      expected = [
        (checkedGroup [
          (duplicate "theme.caelestia.a" "one")
          (duplicate "theme.caelestia.a" "two")
        ])
      ];
    };
    "test duplicates within one matugen group recover through finish" = {
      expr = cells.groups.matugenWithin;
      expected = [ matugenFile ];
    };
    "test each failing theme group recovers on its own" = {
      expr = cells.groups.themeRecovery;
      expected = [
        (checkedGroup [ (duplicate "theme.caelestia.a" "a") ])
        (checkedGroup [ unsupported ])
      ];
    };
    "test a valid theme group survives a failing one" = {
      expr = cells.groups.themeSuccessThenRecovery;
      expected = themeDestinations ++ [ (checkedGroup [ unsupported ]).text ];
    };
    "test a valid theme group reaches no reporter" = {
      expr = cells.groups.themeSuccess;
      expected = themeDestinations;
    };
    "test each failing matugen group recovers on its own" = {
      expr = cells.groups.matugenRecovery;
      expected = [
        matugenFile
        matugenFile
      ];
    };
    "test valid matugen groups finish separately" = {
      expr = cells.groups.matugenSuccess;
      expected = [
        matugenFile
        matugenFile
      ];
    };
    "test a matugen native payload stays opaque" = {
      expr = cells.groups.matugenNativeOpaque;
      expected = [
        matugenFile
        matugenFile
      ];
    };

    "test theme duplicates in one group fail with both lines" = terminal "themeWithin" [
      (themeDuplicate "one")
      (themeDuplicate "two")
    ];
    "test matugen duplicates in one group fail with both lines" = terminal "matugenWithin" [
      (matugenDuplicate "one" "a")
      (matugenDuplicate "two" "a")
    ];
    "test the first failing theme group fails alone" = terminal "themeTwo" [ (themeDuplicate "a") ];
    "test a later poisoned theme stays unforced" = terminal "themePoison" [ (themeDuplicate "a") ];
    "test a valid theme group before a failing one" = terminal "themeSuccessThenFailure" [
      themeUnsupported
    ];
    "test the first failing matugen group fails alone" = terminal "matugenTwo" [
      (matugenDuplicate "duplicate" "a")
    ];
    "test a later poisoned matugen registration stays unforced" = terminal "matugenPoison" [
      (matugenDuplicate "duplicate" "a")
    ];
    "test a valid matugen group before a failing one" = terminal "matugenSuccessThenFailure" [
      (matugenDuplicate "duplicate" "z")
    ];
    "test a matugen native payload after a duplicate stays unforced" =
      terminal "matugenNativeAfterDuplicate"
        [ (matugenDuplicate "duplicate" "a") ];
    "test a later poisoned theme native surfaces its own exception" = {
      expr = cells.exceptions.themeSuccessPoison;
      expectedError.type = "ThrownError";
      expectedError.msg = "^later theme native forced$";
    };
  };
}
