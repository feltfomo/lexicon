{
  lib,
  pkgs,
  krisis,
  axiom,
  lexicon,
}:
let
  ownerships = import ../../src/ownerships { inherit lib krisis axiom; };
  inherit (ownerships) claimKeys;

  merge =
    left: right:
    lib.zipAttrsWith
      (
        _: values:
        if builtins.all builtins.isList values then
          builtins.concatLists values
        else if builtins.all builtins.isAttrs values then
          lib.foldl' merge { } values
        else
          lib.last values
      )
      [
        left
        right
      ];

  # the test resolver isolates the program boundary from the fleet roster
  collect =
    ctx: unit:
    let
      hostName = ctx.host.name or null;
      userName = ctx.user.name or null;
      active =
        (!(unit ? when) || unit.when ctx)
        && (!(unit ? hosts) || builtins.elem hostName unit.hosts)
        && (!(unit ? users) || builtins.elem userName unit.users)
        && (!(unit ? exceptHosts) || !(builtins.elem hostName unit.exceptHosts))
        && (!(unit ? exceptUsers) || !(builtins.elem userName unit.exceptUsers));
      own = removeAttrs unit (claimKeys ++ [ "children" ]);
    in
    if !active then { } else lib.foldl' merge own (map (collect ctx) (unit.children or [ ]));

  containsInOrder =
    fragments: text:
    if fragments == [ ] then
      true
    else
      let
        fragment = builtins.head fragments;
        parts = lib.splitString fragment text;
      in
      builtins.length parts > 1
      && containsInOrder (builtins.tail fragments) (lib.concatStringsSep fragment (builtins.tail parts));

  resolve = units: ctx: lib.foldl' merge { } (map (collect ctx) units);
  resolveSystem = resolve;
  resolvePrepared = resolve;
  program = import ../../src/program.nix {
    inherit
      lib
      krisis
      axiom
      resolve
      resolveSystem
      resolvePrepared
      ;
    mkCoordinator = throw "the program tests forced the furnish coordinator builder";
    filePrincipals = args: [
      {
        authority = {
          scope = "user";
          identity = args.user.name;
        };
      }
    ];
    hostUserNames = _: [ "feltfomo" ];
  };

  moduleArgs = {
    inherit lib pkgs;
    config = {
      networking.hostName = "test";
      lexicon.furnish.declarations = [ { } ];
    };
    host.name = "test";
    user.name = "feltfomo";
  };

  declarationsOfWith =
    args: spec:
    let
      result = spec.nixos args;
      declarationsModule = builtins.head (
        builtins.filter (module: builtins.isAttrs module && module ? lexicon) result.imports
      );
    in
    declarationsModule.lexicon.furnish.declarations;

  declarationsOf = declarationsOfWith moduleArgs;

  packageOnly = program { pkg = pkgs': pkgs'.hello; };
  fileOnly = program {
    files = [
      {
        dest = ".config/example";
        src = ../../src/program.nix;
      }
    ];
  };
  combined = program {
    pkg = pkgs': pkgs'.hello;
    files = [
      {
        dest = ".config/example";
        src = ../../src/program.nix;
      }
    ];
  };
  directoryOnly = program {
    directories = [
      {
        src = ./fixtures/sample-tree;
        dest = ".config/example";
        files = [
          {
            names = [ "default.nix" ];
            representation = "writable";
            onConflict = "runtime-wins";
          }
          {
            names = [ "diagnostics.nix" ];
            hosts = [ "lumi" ];
          }
        ];
      }
    ];
    theme = {
      id = "example";
      renderers.noctalia = {
        source = ./fixtures/sample-tree/safe-render.nix;
        output = ".config/example/safe-render.nix";
      };
    };
  };
  directoryDeclarations = declarationsOf directoryOnly;
  directoryDestinations = map (declaration: declaration.destination) directoryDeclarations;

  dmsOnly = program {
    theme = {
      id = "dms-example";
      renderers.dms = {
        source = ../../src/program.nix;
        output = ".config/example/dms.conf";
        native.compare_to = "dark";
      };
    };
  };
  dmsDestinations = map (declaration: declaration.destination) (declarationsOf dmsOnly);

  illogicalImpulseOnly = program {
    theme = {
      id = "illogical-impulse-example";
      renderers.illogical-impulse = {
        source = ../../src/program.nix;
        output = ".config/example/illogical-impulse.conf";
        native.compare_to = "dark";
      };
    };
  };
  illogicalImpulseDestinations = map (declaration: declaration.destination) (
    declarationsOf illogicalImpulseOnly
  );

  end4PcOnly = program {
    theme = {
      id = "end4-pc-example";
      renderers.end4-pc = {
        source = ../../src/program.nix;
        output = ".config/example/end4-pc.conf";
        native.compare_to = "dark";
      };
    };
  };
  end4PcDestinations = map (declaration: declaration.destination) (declarationsOf end4PcOnly);

  caelestiaOnly = program {
    theme = {
      id = "caelestia-example";
      renderers.caelestia = {
        source = ../../src/program.nix;
        output = ".config/example/caelestia.conf";
        reload = "pkill -SIGUSR1 example";
      };
    };
  };
  caelestiaDestinations = map (declaration: declaration.destination) (declarationsOf caelestiaOnly);

  caelestiaMulti = program {
    theme = {
      id = "caelestia-multi";
      templates = [
        {
          subId = "zeta";
          renderers.caelestia = {
            source = ../../src/program.nix;
            output = ".config/example/zeta.conf";
            reload = "printf zeta";
          };
        }
        {
          subId = "alpha";
          renderers.caelestia = {
            source = ../../src/program.nix;
            output = ".config/example/alpha.conf";
            reload = "printf alpha";
          };
        }
      ];
    };
  };
  caelestiaMultiDeclarations = declarationsOf caelestiaMulti;
  caelestiaMultiDestinations = lib.sort builtins.lessThan (
    map (declaration: declaration.destination) caelestiaMultiDeclarations
  );
  caelestiaMultiHook = builtins.head (
    builtins.filter (
      declaration: declaration.destination == ".config/caelestia/theme-hooks/caelestia-multi"
    ) caelestiaMultiDeclarations
  );
  # the script's text attribute avoids building it, which the sandboxed runner can't do
  caelestiaMultiHookScript = caelestiaMultiHook.source.value.text;
  caelestiaPublishFragments = [
    ".local/state/caelestia/theme/caelestia-multi-alpha-program.nix"
    ".config/example/alpha.conf"
    ".local/state/caelestia/theme/caelestia-multi-zeta-program.nix"
    ".config/example/zeta.conf"
    "printf alpha"
    "printf zeta"
  ];

  dualTheme = program {
    theme = {
      id = "shared";
      source = ../../src/program.nix;
      output = ".config/example/shared.conf";
      renderers.noctalia.sharedWith = [
        "dms"
        "illogical-impulse"
        "end4-pc"
        "caelestia"
      ];
    };
  };
  dualThemeDestinations = map (declaration: declaration.destination) (declarationsOf dualTheme);

  reverseSharedTheme = program {
    theme = {
      id = "reverse-shared";
      source = ../../src/program.nix;
      output = ".config/example/reverse-shared.conf";
      renderers.dms.sharedWith = [ "noctalia" ];
    };
  };
  reverseSharedDestinations = map (declaration: declaration.destination) (
    declarationsOf reverseSharedTheme
  );
  writableDeclaration = builtins.head (
    builtins.filter (
      declaration: declaration.destination == ".config/example/default.nix"
    ) directoryDeclarations
  );

  subtreeDirectory = program {
    directories = [
      {
        src = ./fixtures/prunable;
        dest = ".config/furnish-source";
        exclude = [ "nested" ];
      }
    ];
  };
  subtreeDeclarations = declarationsOf subtreeDirectory;
  subtreeDestinations = map (declaration: declaration.destination) subtreeDeclarations;

  userOnly = program {
    files = [
      {
        users = [ "feltfomo" ];
        dest = ".config/user-only";
        src = ../../src/program.nix;
      }
    ];
  };
  exceptFeltfomo = program {
    files = [
      {
        exceptUsers = [ "feltfomo" ];
        dest = ".config/except-user";
        src = ../../src/program.nix;
      }
    ];
  };
  grandpaArgs = moduleArgs // {
    user.name = "grandpa";
  };

  unknownFileField = program {
    files = [
      {
        dest = ".config/unknown";
        src = ../../src/program.nix;
        typo = true;
      }
    ];
  };
  unknownDmsField = program {
    theme = {
      id = "invalid";
      renderers.dms = {
        source = ../../src/program.nix;
        output = ".config/invalid";
        typo = true;
      };
    };
  };
  unsupportedCaelestiaNative = program {
    theme = {
      id = "invalid-native";
      renderers.caelestia = {
        source = ../../src/program.nix;
        output = ".config/invalid-native";
        native.format = "unsupported";
      };
    };
  };
  emptyRenderer = program {
    theme = {
      id = "empty-renderer";
      renderers.dms = { };
    };
  };
  inheritedRendererFields = program {
    theme = {
      id = "inherited-renderer";
      source = ../../src/program.nix;
      output = ".config/inherited-renderer";
      placedAs = "shared.nix";
      renderers = {
        dms = { };
        noctalia.placedAs = "override.nix";
      };
    };
  };
  inheritedRendererDeclarations = declarationsOf inheritedRendererFields;
  inheritedRendererDestinations = map (
    declaration: declaration.destination
  ) inheritedRendererDeclarations;
  unknownSharedShell = program {
    theme = {
      id = "unknown-shared-shell";
      source = ../../src/program.nix;
      output = ".config/unknown-shared-shell";
      renderers.noctalia.sharedWith = [ "ds" ];
    };
  };
  duplicateSharedShell = program {
    theme = {
      id = "duplicate-shared-shell";
      source = ../../src/program.nix;
      output = ".config/duplicate-shared-shell";
      renderers.noctalia.sharedWith = [
        "dms"
        "dms"
      ];
    };
  };
  selfSharedShell = program {
    theme = {
      id = "self-shared-shell";
      source = ../../src/program.nix;
      output = ".config/self-shared-shell";
      renderers.noctalia.sharedWith = [ "noctalia" ];
    };
  };
  overlappingSharedShell = program {
    theme = {
      id = "overlapping-shared-shell";
      source = ../../src/program.nix;
      output = ".config/overlapping-shared-shell";
      renderers = {
        noctalia.sharedWith = [ "dms" ];
        dms = { };
      };
    };
  };
  invalidPolicy = program {
    files = [
      {
        dest = ".config/policy";
        src = ../../src/program.nix;
        onConflict = "merge";
      }
    ];
  };
  excludedOverride = program {
    directories = [
      {
        src = ./fixtures/prunable;
        dest = ".config/furnish-source";
        exclude = [ "nested" ];
        files = [
          {
            names = [ "nested/inner.toml" ];
            representation = "writable";
          }
        ];
      }
    ];
  };
  excludedTheme = program {
    directories = [
      {
        src = ./fixtures/prunable;
        dest = ".config/furnish-source";
        exclude = [ "nested" ];
      }
    ];
    theme = {
      id = "excluded";
      renderers.noctalia = {
        source = ./fixtures/prunable/nested/inner.toml;
        output = ".config/excluded.toml";
      };
    };
  };

  inactiveMalformed = program {
    files = [
      {
        when = _: false;
        dest = 1;
      }
    ];
  };
  inactiveDirectory = program {
    directories = [
      {
        when = _: false;
        src = throw "forced inactive directory source";
        dest = ".config/inactive";
      }
    ];
  };
  inactiveTheme = program {
    theme = {
      id = "inactive-theme";
      when = _: false;
      renderers.caelestia = {
        source = throw "forced inactive theme source";
        output = ".config/inactive-theme";
      };
    };
  };
  selectedMalformed = program {
    files = [
      {
        dest = 1;
      }
    ];
  };
  selectedMalformedDirectory = program {
    directories = [
      {
        src = ../../src/program.nix;
        dest = ".config/not-a-directory";
      }
    ];
  };
  selectedMissingDirectory = program {
    directories = [
      {
        src = "${./.}/program-tests-missing-directory";
        dest = ".config/missing-directory";
      }
    ];
  };

in
{
  "test suggestions use shared policy" = {
    expr =
      let
        report = import ../../src/program/report.nix { inherit lib krisis axiom; };
      in
      report.suggest [ "bat" "car" ] "cat" == "bat"
      && report.suggestionFor [ "bat" "car" ] "cat" == " -- did you mean 'bat'?"
      && report.suggestionFor [ "unrelated" ] "cat" == ""
      && report.editDistance "kitten" "sitting" == 3;
    expected = true;
  };
  "test bounded output shapes" = {
    expr =
      builtins.attrNames packageOnly == [ "homeManager" ]
      && builtins.attrNames fileOnly == [ "nixos" ]
      && builtins.attrNames directoryOnly == [ "nixos" ]
      &&
        builtins.attrNames combined == [
          "homeManager"
          "nixos"
        ];
    expected = true;
  };
  "test package only shape" = {
    expr = packageOnly ? homeManager && !(packageOnly ? nixos);
    expected = true;
  };
  "test file only shape" = {
    expr = fileOnly ? nixos && !(fileOnly ? homeManager);
    expected = true;
  };
  "test combined shape" = {
    expr = combined ? homeManager && combined ? nixos;
    expected = true;
  };
  "test inactive payload stays lazy" = {
    expr = builtins.deepSeq (inactiveMalformed.nixos moduleArgs) true;
    expected = true;
  };
  "test inactive directory stays lazy" = {
    expr = builtins.deepSeq (inactiveDirectory.nixos moduleArgs) true;
    expected = true;
  };
  "test inactive theme adapter stays lazy" = {
    expr = builtins.deepSeq (inactiveTheme.nixos moduleArgs) true;
    expected = true;
  };
  "test selected payload is validated" = {
    expr = selectedMalformed.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/resource/shape\\] \\$\\.furnish\\.files\\[0\\]\\.destination: invalid resource field";
  };
  "test selected nondirectory source is rejected" = {
    expr = selectedMalformedDirectory.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/directory-source-kind\\] \\$\\.furnish\\.directories\\[0\\]: src must be a directory: ";
  };
  "test selected missing directory source is rejected" = {
    expr = selectedMissingDirectory.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/directory-source-missing\\] \\$\\.furnish\\.directories\\[0\\]: src does not exist in the flake source: ";
  };
  "test directory members expand to files" = {
    expr = builtins.elem ".config/example/default.nix" directoryDestinations;
    expected = true;
  };
  "test inactive overrides do not fall back" = {
    expr = !(builtins.elem ".config/example/diagnostics.nix" directoryDestinations);
    expected = true;
  };
  "test noctalia sources are reserved" = {
    expr =
      !(builtins.elem ".config/example/safe-render.nix" directoryDestinations)
      && builtins.elem ".config/noctalia/templates/example/safe-render.nix" directoryDestinations;
    expected = true;
  };
  "test dms templates lower to independent fragments" = {
    expr =
      builtins.elem ".config/matugen/dms/templates/dms-example/program.nix" dmsDestinations
      && !(builtins.any (
        destination: lib.hasPrefix ".config/matugen/dms/configs/" destination
      ) dmsDestinations);
    expected = true;
  };
  "test illogical impulse templates lower to independent fragments" = {
    expr = builtins.elem ".config/illogical-impulse/matugen/templates/illogical-impulse-example/program.nix" illogicalImpulseDestinations;
    expected = true;
  };
  "test end4 pc templates lower to independent fragments" = {
    expr = builtins.elem ".config/end4-pc/matugen/templates/end4-pc-example/program.nix" end4PcDestinations;
    expected = true;
  };
  "test caelestia templates lower to state publishers" = {
    expr =
      builtins.elem ".config/caelestia/templates/caelestia-example-program.nix" caelestiaDestinations
      && builtins.elem ".config/caelestia/theme-hooks/caelestia-example" caelestiaDestinations;
    expected = true;
  };
  "test caelestia multi output destinations are exact" = {
    expr = caelestiaMultiDestinations;
    expected = [
      ".config/caelestia/templates/caelestia-multi-alpha-program.nix"
      ".config/caelestia/templates/caelestia-multi-zeta-program.nix"
      ".config/caelestia/theme-hooks/caelestia-multi"
    ];
  };
  "test caelestia publishers are strict and transactionally ordered" = {
    expr =
      lib.hasInfix "set -eu" caelestiaMultiHookScript
      && containsInOrder caelestiaPublishFragments caelestiaMultiHookScript;
    expected = true;
  };
  "test shared registration emits all backends" = {
    expr =
      builtins.elem ".config/noctalia/templates/shared/program.nix" dualThemeDestinations
      && builtins.elem ".config/noctalia/shared.toml" dualThemeDestinations
      && builtins.elem ".config/matugen/dms/templates/shared/program.nix" dualThemeDestinations
      && builtins.elem ".config/illogical-impulse/matugen/templates/shared/program.nix" dualThemeDestinations
      && builtins.elem ".config/end4-pc/matugen/templates/shared/program.nix" dualThemeDestinations
      && builtins.elem ".config/caelestia/templates/shared-program.nix" dualThemeDestinations
      && builtins.elem ".config/caelestia/theme-hooks/shared" dualThemeDestinations
      && !(builtins.any (
        destination: lib.hasPrefix ".config/matugen/dms/configs/" destination
      ) dualThemeDestinations);
    expected = true;
  };
  "test shared registration is direction independent" = {
    expr =
      builtins.elem ".config/noctalia/templates/reverse-shared/program.nix" reverseSharedDestinations
      && builtins.elem ".config/noctalia/reverse-shared.toml" reverseSharedDestinations
      && builtins.elem ".config/matugen/dms/templates/reverse-shared/program.nix" reverseSharedDestinations;
    expected = true;
  };
  "test writable overrides are first class" = {
    expr =
      writableDeclaration.representation == "writable"
      && writableDeclaration.onConflict == "runtime-wins";
    expected = true;
  };
  "test directory subtrees are pruned" = {
    expr = !(builtins.any (destination: lib.hasInfix "/nested/" destination) subtreeDestinations);
    expected = true;
  };
  "test directory member sources stay path typed" = {
    expr = builtins.all (declaration: builtins.isPath declaration.source.value) subtreeDeclarations;
    expected = true;
  };
  "test user claims select the current user" = {
    expr =
      builtins.length (declarationsOf userOnly) == 1 && declarationsOfWith grandpaArgs userOnly == [ ];
    expected = true;
  };
  "test except user claims select everyone else" = {
    expr =
      declarationsOf exceptFeltfomo == [ ]
      && builtins.length (declarationsOfWith grandpaArgs exceptFeltfomo) == 1;
    expected = true;
  };
  "test unknown file fields are rejected" = {
    expr = unknownFileField.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.furnish\\.files\\[0\\]\\.typo: unregistered field typo";
  };
  "test unknown dms fields are rejected" = {
    expr = unknownDmsField.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/unknown-field\\] \\$\\.theme\\.renderers\\.dms\\.typo: unregistered field typo";
  };
  "test caelestia native fields are rejected" = {
    expr = unsupportedCaelestiaNative.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "program: 1 declaration error\\(s\\)\n\\s*- \\[program/theme-native-unsupported\\] theme\\.caelestia\\.invalid-native: cannot use native registration fields: in";
  };
  "test empty renderers are rejected" = {
    expr = emptyRenderer.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/theme-renderer-incomplete\\] \\$\\.theme\\.renderers\\.dms: effective renderer settings must define source and ";
  };
  "test inherited renderer fields are supported" = {
    expr =
      builtins.elem ".config/matugen/dms/templates/inherited-renderer/shared.nix" inheritedRendererDestinations
      && builtins.elem ".config/noctalia/templates/inherited-renderer/override.nix" inheritedRendererDestinations;
    expected = true;
  };
  "test unknown shared shells are rejected" = {
    expr = unknownSharedShell.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/theme-renderer-unknown\\] \\$\\.theme\\.renderers\\.noctalia\\.sharedWith: unknown shell \"ds\"";
  };
  "test duplicate shared shells are rejected" = {
    expr = duplicateSharedShell.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/theme-renderer-shared-duplicate\\] \\$\\.theme\\.renderers\\.noctalia\\.sharedWith: sharedWith repeats shells: dm";
  };
  "test self shared shells are rejected" = {
    expr = selfSharedShell.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/theme-renderer-shared-self\\] \\$\\.theme\\.renderers\\.noctalia\\.sharedWith: a renderer cannot share with itsel";
  };
  "test overlapping shared shells are rejected" = {
    expr = overlappingSharedShell.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/theme-renderer-overlap\\] \\$\\.theme\\.renderers\\.dms: shell dms is assigned by multiple renderer declaration";
  };
  "test invalid conflict policies are rejected" = {
    expr = invalidPolicy.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[lexicon/resource/shape\\] \\$\\.furnish\\.files\\[0\\]\\.onConflict: invalid resource field";
  };
  "test overrides beneath excluded subtrees are rejected" = {
    expr = excludedOverride.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/directory-file-excluded\\] \\$\\.furnish\\.directories\\[0\\]: overrides excluded names: nested/inner\\.toml";
  };
  "test theme sources beneath excluded subtrees are rejected" = {
    expr = excludedTheme.nixos moduleArgs;
    expectedError.type = "ThrownError";
    expectedError.msg = "\\[program/directory-theme-excluded\\] \\$\\.furnish\\.directories\\[0\\]: excludes theme sources: nested/inner\\.toml";
  };
}
