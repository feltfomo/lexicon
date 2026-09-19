{
  pkgs,
  nixpkgs,
  lexicon,
}:
let
  inherit (pkgs) lib;
  # the example keeps a simple system choice while each gate uses its own packages
  exampleInputs = {
    inherit lexicon;
    nixpkgs = nixpkgs // {
      legacyPackages.x86_64-linux = pkgs;
    };
  };
  # the documented projects are loaded the way the installed dispatcher loads
  # them: through the praxis output their flake.nix exposes
  compilePraxis =
    directory:
    let
      project = (import (directory + "/flake.nix")).outputs exampleInputs;
    in
    lexicon.lib.praxis (
      {
        inherit pkgs;
        root = directory;
      }
      // project.praxis {
        inherit pkgs;
        root = directory;
      }
    );
  praxisExamples = {
    minimal = compilePraxis ../examples/praxis-minimal;
    commands = compilePraxis ../examples/praxis-commands;
    parameters = compilePraxis ../examples/praxis-parameters;
    scripts = compilePraxis ../examples/praxis-scripts;
    outputs = (import ../examples/praxis-outputs/flake.nix).outputs exampleInputs;
    publish = (import ../examples/praxis-publish/flake.nix).outputs exampleInputs;
    workflow = compilePraxis ../examples/praxis-workflow;
    ownerships = (import ../examples/praxis-ownerships/flake.nix).outputs exampleInputs;
    project = compilePraxis ../examples/praxis-project;
  };
  # each documented placement is evaluated separately, from the file the reader
  # is told to copy, rather than from one combined flake
  installRoute =
    let
      system = pkgs.stdenv.hostPlatform.system;
      wanted = "${genericPraxis}";
      has = list: builtins.elem wanted (map toString list);
      nixosPlacement = (import ../examples/praxis-install/flake.nix).outputs exampleInputs;
      homePlacement = lib.evalModules {
        modules = [
          ../examples/praxis-install/home.nix
          {
            config._module.args.pkgs = pkgs;
            config._module.args.inputs = exampleInputs;
            options.home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
          }
        ];
      };
      shellProject = (import ../examples/praxis-shell/flake.nix).outputs exampleInputs;
    in
    {
      nixosSystemPackage = has nixosPlacement.nixosConfigurations.workstation.config.environment.systemPackages;
      homePackage = has homePlacement.config.home.packages;
      devShellPackage = has (shellProject.devShells.${system}.default.nativeBuildInputs or [ ]);
    };
  minimalEdited = lexicon.lib.praxis {
    inherit pkgs;
    root = ../examples/praxis-minimal;
    commands.inspect = [
      "nix"
      "eval"
      "--raw"
      ".#detailedStatus"
    ];
  };
  genericPraxis = lexicon.packages.${pkgs.stdenv.hostPlatform.system}.praxis;
  praxisClosure = pkgs.closureInfo {
    rootPaths = [
      genericPraxis
      pkgs.path
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      pkgs.nix
      pkgs.stdenv
      pkgs.stdenvNoCC
      ((import ../examples/praxis-project/flake.nix).outputs exampleInputs)
      .packages.${pkgs.stdenv.hostPlatform.system}.default
      ((import ../examples/praxis-project/flake.nix).outputs exampleInputs)
      .checks.${pkgs.stdenv.hostPlatform.system}.artifact
    ];
  };
  preferences = (import ../examples/ownerships/flake.nix).outputs exampleInputs;
  trial = import ./ownerships-examples.nix { inherit lexicon nixpkgs; };
  furnishTrial = import ./furnish-examples.nix { inherit lexicon nixpkgs; };
  programTrial = import ./program-examples.nix { inherit lexicon nixpkgs; };
  praxisTrial = import ./praxis-examples.nix { inherit lexicon nixpkgs; };
  furnishExample = (import ../examples/furnish/flake.nix).outputs { inherit nixpkgs lexicon; };
  setup = import ../examples/workstation/setup.nix { inherit lexicon pkgs; };
  alice = setup.forUser "alice";
  system = nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      alice.nixos
      {
        boot.isContainer = true;
        networking.hostName = "workstation";
        users.users.alice.isNormalUser = true;
        lexicon.furnish.enable = true;
        system.stateVersion = "26.05";
      }
    ];
  };
  home = lib.evalModules {
    modules = [
      alice.homeManager
      {
        config._module.args.pkgs = pkgs;
        options.home.packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
        options.home.sessionVariables = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
        };
      }
    ];
  };
  values = pkgs.writeText "lexicon-example-values.json" (
    assert trial.ok;
    assert furnishTrial.ok;
    assert programTrial.ok;
    assert praxisTrial.ok;
    builtins.toJSON {
      ownerships = { inherit (trial) samples exports expectedFailures; };
      furnish = {
        inherit (furnishTrial)
          samples
          flakeExports
          exports
          contractExports
          coreExports
          filesExports
          resultFields
          manifestEntryFields
          optionNames
          ;
      };
      programDocs = {
        inherit (programTrial)
          samples
          inventories
          expectedFailures
          ;
      };
      praxisInstall = installRoute;
      praxisDocs = {
        inherit (praxisTrial) samples inventories;
        executables = {
          generic = "${genericPraxis}/bin/praxis";
          minimal = "${praxisExamples.minimal.package}/bin/praxis";
          minimalEdited = "${minimalEdited.package}/bin/praxis";
          commands = "${praxisExamples.commands.package}/bin/praxis";
          parameters = "${praxisExamples.parameters.package}/bin/praxis";
          scripts = "${praxisExamples.scripts.package}/bin/praxis";
          outputs = "${praxisExamples.outputs.packages.${pkgs.stdenv.hostPlatform.system}.work}/bin/work";
          publish = "${praxisExamples.publish.packages.${pkgs.stdenv.hostPlatform.system}.praxis}/bin/praxis";
          # the per-command app the outputs guide runs as its third door
          publishCommand = "${
            praxisExamples.publish.packages.${pkgs.stdenv.hostPlatform.system}.greet
          }/bin/greet";
          # a wrapper executable from the all-switches comparison flake
          outputsWrapper = "${
            praxisExamples.outputs.packages.${pkgs.stdenv.hostPlatform.system}.work
          }/bin/unit";
          workflow = "${praxisExamples.workflow.package}/bin/praxis";
          ownerships = "${
            praxisExamples.ownerships.packages.${pkgs.stdenv.hostPlatform.system}.praxis
          }/bin/praxis";
          project = "${praxisExamples.project.package}/bin/praxis";
        };
        selectedChecks = [
          "${praxisExamples.scripts.checks.source-check}"
          "${praxisExamples.outputs.checks.${pkgs.stdenv.hostPlatform.system}.unit}"
          # the flake check the outputs guide tells continuous integration to run
          "${praxisExamples.publish.checks.${pkgs.stdenv.hostPlatform.system}.greet}"
        ];
      };
      preferences = { inherit (preferences.lib) alice sam laptop; };
      home = {
        packages = map (package: package.pname) home.config.home.packages;
        editor = home.config.home.sessionVariables.EDITOR;
      };
      legacyFurnish = furnishExample.nixosConfigurations.demo.config.lexicon.furnish.manifestData;
      program = system.config.lexicon.furnish.manifestData;
      target = setup.host.id;
    }
  );
  documents = import ./documentation-source.nix;
in
pkgs.runCommandLocal "lexicon-documentation"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
      pkgs.fish
      pkgs.gnugrep
      pkgs.jq
      pkgs.lychee
      pkgs.nix
      pkgs.ripgrep
      pkgs.zsh
    ];
  }
  ''
    set -euo pipefail
    root=${documents}
    values=${values}
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export NIX_CONFIG='experimental-features = nix-command flakes pipe-operators'
    cd "$root"

    test "$(jq -c '.preferences.alice' "$values")" = '["tools",["git","helix"]]' || \
      jq -e '.preferences.alice == {tools:["git","helix"]}' "$values"
    jq -e '.preferences.sam == {tools:["git"]}' "$values"
    jq -e '.preferences.laptop == {tools:["git","helix"],lowPower:true}' "$values"
    jq -e '.home == {packages:["helix"],editor:"hx"}' "$values"
    # the documented declarative installation route, not a harness injection
    jq -e '.praxisInstall == {nixosSystemPackage:true,homePackage:true,devShellPackage:true}' "$values"

    # hygiene: exactly one intentional first-person reference to the private
    # configuration, in the Den guide; the pattern is written so this check
    # never matches itself
    rg -i --no-heading -n 'sk[a]di' README.md docs examples src tests > "$TMPDIR/private-ref" || true
    test "$(grep -c . "$TMPDIR/private-ref" || true)" -eq 1
    grep -q '^docs/program/den.md:' "$TMPDIR/private-ref"
    # no imperative Praxis installation route and no public outputs.nix recipe
    test -z "$(rg -l 'nix profile' README.md docs examples || true)"
    # nix run reaches Praxis commands without installing anything, which is the
    # whole subject of the flake outputs guide; it stays banned everywhere else
    # so it can never become an installation or everyday route
    test -z "$(
      rg -l 'nix run .*praxis' README.md docs examples --glob '!docs/praxis/outputs.md' || true
    )"
    rg -q 'nix run .*praxis' docs/praxis/outputs.md
    test -z "$(rg -l 'outputs\.nix' README.md docs examples || true)"
    # no public wording that makes a neighboring praxis.nix mandatory
    test -z "$(rg -l 'declared by praxis.nix|neighboring praxis.nix|praxis.nix beside' README.md docs examples src || true)"
    # deleted artifacts stay deleted and Praxis stays Python-free
    test ! -e docs/validation.md
    test ! -e tests/praxis/benchmark.nix
    test ! -e tests/praxis/snapshots.json
    test -z "$(find src/praxis tests/praxis -name '*.py' || true)"
    test -z "$(rg -l 'python3?' src/praxis tests/praxis || true)"

    test ! -e old-docs
    test -f README.md
    test -f docs/README.md
    for area in ownerships furnish program praxis; do
      test -f "docs/$area/README.md"
    done

    SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
      lychee --offline --include-fragments README.md docs examples

    check_blocks() {
      marker="$1"
      while IFS=: read -r file number line; do
        target=$(printf '%s\n' "$line" | sed -n "s/.*<!-- $marker: \(.*\) -->.*/\1/p")
        test -n "$target"
        start=$((number + 2))
        end=$(tail -n +"$start" "$file" | grep -n -m1 '^```$' | cut -d: -f1)
        test -n "$end"
        end=$((start + end - 2))
        block="$TMPDIR/block"
        sed -n "''${start},''${end}p" "$file" > "$block"
        resolved=$(realpath -m "$(dirname "$file")/$target")
        case "$resolved" in "$root"/*) ;; *) exit 1 ;; esac
        test -f "$resolved"
        if test "$marker" = source; then
          cmp "$resolved" "$block"
        else
          count=$(rg -U -F -c "$(cat "$block")" "$resolved" || true)
          test "$count" -eq 1
        fi
      done < <(rg -n --no-heading "<!-- $marker:" README.md docs examples || true)
    }
    check_blocks source
    check_blocks excerpt

    check_values() {
      marker="$1"
      while IFS=: read -r file number line; do
        key=$(printf '%s\n' "$line" | sed -n "s/.*<!-- $marker: \(.*\) -->.*/\1/p")
        start=$((number + 2))
        end=$(tail -n +"$start" "$file" | grep -n -m1 '^```$' | cut -d: -f1)
        end=$((start + end - 2))
        sed -n "''${start},''${end}p" "$file" > "$TMPDIR/value"
        jq -e --arg key "$key" --slurpfile actual "$TMPDIR/value" '
          .ownerships.samples[$key] == $actual[0] or
          .furnish.samples[$key] == $actual[0] or
          .programDocs.samples[$key] == $actual[0] or
          .praxisDocs.samples[$key] == $actual[0]
        ' "$values"
      done < <(rg -n --no-heading "<!-- $marker:" docs || true)
    }
    for marker in value furnish-value program-value praxis-value; do
      count=$(rg -l "<!-- $marker:" docs | wc -l)
      test "$count" -gt 0
      check_values "$marker"
    done

    check_inventory() {
      area="$1"
      marker="$2"
      query="$3"
      required="''${4:-1}"
      matches=$(rg -o "<!-- $marker: [^>]* -->" "docs/$area" || true)
      test "$(printf '%s\n' "$matches" | grep -c .)" -eq "$required"
      expected=$(jq -r "$query[]" "$values" | sort)
      test -n "$expected"
      while IFS= read -r match; do
        actual=$(printf '%s\n' "$match" | sed -E "s/.*<!-- $marker: ([^>]*) -->/\\1/" | tr ' ' '\n' | grep . | sort)
        test "$(printf '%s\n' "$actual" | uniq -d | wc -l)" -eq 0
        test "$actual" = "$expected"
      done <<< "$matches"
      while IFS= read -r name; do
        rg -U '`[^`\n]*'"$name"'[^`\n]*`' "docs/$area" >/dev/null
      done <<< "$expected"
    }

    check_inventory furnish furnish-flake-exports '.furnish.flakeExports'
    check_inventory furnish furnish-exports '.furnish.exports'
    check_inventory furnish furnish-contract-exports '.furnish.contractExports'
    check_inventory furnish furnish-core-exports '.furnish.coreExports'
    check_inventory furnish furnish-files-exports '.furnish.filesExports'
    check_inventory furnish furnish-result-fields '.furnish.resultFields' 2
    check_inventory furnish furnish-manifest-entry-fields '.furnish.manifestEntryFields'
    check_inventory furnish furnish-options '.furnish.optionNames'
    check_inventory program program-constructors '.programDocs.inventories.constructors'
    check_inventory program program-claim-fields '.programDocs.inventories.claims'
    check_inventory program program-fields '.programDocs.inventories.spec'
    check_inventory program program-file-fields '.programDocs.inventories.file'
    check_inventory program program-directory-fields '.programDocs.inventories.directory'
    check_inventory program program-directory-rule-fields '.programDocs.inventories.directoryRule'
    check_inventory program program-theme-fields '.programDocs.inventories.theme'
    check_inventory program program-template-fields '.programDocs.inventories.template'
    check_inventory program program-renderer-fields '.programDocs.inventories.renderer'
    check_inventory program program-target-fields '.programDocs.inventories.target'
    check_inventory program program-host-fields '.programDocs.inventories.host'
    check_inventory program program-user-fields '.programDocs.inventories.user'
    check_inventory program program-theme-backends '.programDocs.inventories.backends'
    check_inventory program program-outputs '.programDocs.inventories.outputs'
    check_inventory praxis praxis-constructors '.praxisDocs.inventories.constructors'
    check_inventory praxis praxis-project-fields '.praxisDocs.inventories.projectFields'
    check_inventory praxis praxis-action-fields '.praxisDocs.inventories.actionFields'
    check_inventory praxis praxis-parameter-fields '.praxisDocs.inventories.parameterFields'
    check_inventory praxis praxis-parameter-types '.praxisDocs.inventories.parameterTypes'
    check_inventory praxis praxis-result-fields '.praxisDocs.inventories.resultFields'
    check_inventory praxis praxis-adapter-fields '.praxisDocs.inventories.adapterFields'
    while IFS= read -r constructor; do
      rg -U "lexicon\\.lib\\.$constructor\\b" docs/program >/dev/null
    done < <(jq -r '.programDocs.inventories.constructors[]' "$values")

    check_selectors() {
      area="$1"
      evaluator="$2"
      query="$3"
      expected_count="$4"
      selectors=$(rg -o "nix eval[^\\n]*--file $evaluator [A-Za-z0-9_.-]+" "docs/$area" | sed -E 's/.* //' | sort -u)
      test "$(printf '%s\n' "$selectors" | grep -c .)" -eq "$expected_count"
      allowed=$(jq -r "($query)[]" "$values" | sort -u)
      unknown=$(comm -23 <(printf '%s\n' "$selectors") <(printf '%s\n' "$allowed"))
      test -z "$unknown"
    }
    check_selectors ownerships examples/ownerships-eval.nix '(.ownerships.samples | keys) + .ownerships.expectedFailures' 22
    check_selectors furnish examples/furnish-eval.nix '(.furnish.samples | keys)' 4
    check_selectors program examples/program-eval.nix '(.programDocs.samples | keys) + .programDocs.expectedFailures' 12
    check_selectors . examples/praxis-eval.nix '(.praxisDocs.samples | keys)' 2
    command_markers=$(rg -o --no-filename '<!-- praxis-command: [A-Za-z0-9.-]+ -->' docs/praxis/*.md)
    output_markers=$(rg -o --no-filename '<!-- praxis-output: [A-Za-z0-9.-]+ -->' docs/praxis/*.md)
    command_count=$(rg -c '<!-- praxis-command:' docs/praxis/*.md | awk -F: '{ total += $2 } END { print total }')
    output_count=$(rg -c '<!-- praxis-output:' docs/praxis/*.md | awk -F: '{ total += $2 } END { print total }')
    test "$command_count" -gt 0
    test "$output_count" -gt 0
    test "$(printf '%s\n' "$command_markers" | grep -c .)" -eq "$command_count"
    test "$(printf '%s\n' "$output_markers" | grep -c .)" -eq "$output_count"
    test "$(printf '%s\n' "$command_markers" | sort | uniq -d | wc -l)" -eq 0
    test "$(printf '%s\n' "$output_markers" | sort | uniq -d | wc -l)" -eq 0
    printf '%s\n' "$command_markers" | sed -E 's/<!-- praxis-command: ([^ ]+) -->/\1/' | sort > "$TMPDIR/documented-commands"
    : > "$TMPDIR/validated-commands"
    praxis_command() {
      key="$1"
      expected="$2"
      matches=$(rg -n --no-heading "^<!-- praxis-command: $key -->$" "$root/docs/praxis" || true)
      test "$(printf '%s\n' "$matches" | grep -c .)" -eq 1 || {
        echo "praxis-command $key must occur exactly once" >&2
        return 1
      }
      file="''${matches%%:*}"
      rest="''${matches#*:}"
      number="''${rest%%:*}"
      test "$(sed -n "$((number + 1))p" "$file")" = '```sh' || {
        echo "praxis-command $key must be immediately followed by a fenced sh block" >&2
        return 1
      }
      start=$((number + 2))
      length=$(tail -n +"$start" "$file" | grep -n -m1 '^```$' | cut -d: -f1)
      test -n "$length" || {
        echo "praxis-command $key has no closing fence" >&2
        return 1
      }
      end=$((start + length - 2))
      sed -n "''${start},''${end}p" "$file" > "$TMPDIR/praxis-command-actual"
      printf '%s\n' "$expected" > "$TMPDIR/praxis-command-expected"
      cmp "$TMPDIR/praxis-command-expected" "$TMPDIR/praxis-command-actual" || {
        echo "praxis-command $key displayed command drifted" >&2
        return 1
      }
      printf '%s\n' "$key" >> "$TMPDIR/validated-commands"
    }

    praxis_output() {
      key="$1"
      destination="$2"
      matches=$(rg -n --no-heading "<!-- praxis-output: $key -->" "$root/docs/praxis" || true)
      test "$(printf '%s\n' "$matches" | grep -c .)" -eq 1
      file="''${matches%%:*}"
      rest="''${matches#*:}"
      number="''${rest%%:*}"
      start=$((number + 2))
      length=$(tail -n +"$start" "$file" | grep -n -m1 '^```$' | cut -d: -f1)
      test -n "$length"
      end=$((start + length - 2))
      sed -n "''${start},''${end}p" "$file" > "$destination"
    }
    compare_praxis() {
      key="$1"
      shift
      praxis_output "$key" "$TMPDIR/praxis-expected"
      "$@" > "$TMPDIR/praxis-actual"
      if jq -e . "$TMPDIR/praxis-expected" >/dev/null 2>&1 && jq -e . "$TMPDIR/praxis-actual" >/dev/null 2>&1; then
        jq -S . "$TMPDIR/praxis-expected" > "$TMPDIR/praxis-expected.json"
        jq -S . "$TMPDIR/praxis-actual" > "$TMPDIR/praxis-actual.json"
        cmp "$TMPDIR/praxis-expected.json" "$TMPDIR/praxis-actual.json"
      else
        cmp "$TMPDIR/praxis-expected" "$TMPDIR/praxis-actual"
      fi
    }
    praxis_work="$TMPDIR/praxis-docs"
    generic=$(jq -r '.praxisDocs.executables.generic' "$values")
    test_root="$TMPDIR/nix-root"
    test_store="local?root=$test_root"
    mkdir -p "$test_root/nix/store"
    while IFS= read -r path; do
      cp -a "$path" "$test_root/nix/store/"
    done < ${praxisClosure}/store-paths
    nix-store --store "$test_store" --load-db < ${praxisClosure}/registration
    export NIX_REMOTE="$test_store"
    prepare_project() {
      name="$1"
      rm -rf "$praxis_work"
      mkdir -p "$praxis_work/work"
      cp -R "$root/examples/praxis-$name/." "$praxis_work/"
      chmod -R u+w "$praxis_work"
      sed -i 's#github:NixOS/nixpkgs/nixos-unstable#path:${pkgs.path}#' "$praxis_work/flake.nix"
      cd "$praxis_work"
      nix flake lock --offline >/dev/null
    }

    praxis_command outputs.summary 'nix eval --impure --json --file examples/praxis-eval.nix outputs'
    cd "$root"
    jq -e '.praxisDocs.samples.outputs | .hasDevShell == true and (.apps | length > 0) and (.checks | length > 0) and (.packages | length > 0)' "$values"
    praxis_command ownerships.summary 'nix eval --impure --json --file examples/praxis-eval.nix ownerships'
    jq -e '.praxisDocs.samples.ownerships | .denMatches == true and (.hostChoices | length > 0) and (.names | length > 0) and (.userChoices | length > 0)' "$values"

    # the outputs guide runs one command through each published door; the two
    # compared outputs must be identical, because they are the same program
    publish=$(jq -r '.praxisDocs.executables.publish' "$values")
    publish_command=$(jq -r '.praxisDocs.executables.publishCommand' "$values")
    outputs_wrapper=$(jq -r '.praxisDocs.executables.outputsWrapper' "$values")
    praxis_command publish.greet 'praxis --quiet greet'
    compare_praxis publish.greet "$publish" --quiet greet
    # nix run builds this same dispatcher on demand, so the published program
    # stands in for the invocation the guide displays
    praxis_command publish.visitor 'nix run .#praxis -- --quiet greet'
    compare_praxis publish.visitor "$publish" --quiet greet
    # a per-command app takes no dispatcher flags, so it is run, not compared
    praxis_command publish.percommand 'nix run .#greet'
    "$publish_command" >/dev/null
    praxis_command outputs.wrapper 'work unit'
    "$outputs_wrapper" >/dev/null

    praxis_command getting.version 'praxis --version'
    compare_praxis getting.version "$generic" --version
    prepare_project minimal
    praxis_command getting.inspect 'praxis inspect'
    compare_praxis getting.inspect "$generic" inspect
    sed -i 's/.#status/.#detailedStatus/' flake.nix
    praxis_command getting.edited 'praxis inspect'
    compare_praxis getting.edited "$generic" inspect

    prepare_project everyday
    praxis_command everyday.hosts 'praxis hosts'
    compare_praxis everyday.hosts "$generic" hosts
    praxis_command everyday.list 'praxis list'
    compare_praxis everyday.list "$generic" list
    praxis_command everyday.check 'praxis --quiet check'
    "$generic" --quiet check
    praxis_command everyday.target 'praxis target server'
    compare_praxis everyday.target "$generic" target server
    praxis_command everyday.help-rebuild 'praxis help rebuild'
    "$generic" help rebuild >/dev/null

    prepare_project commands
    praxis_command commands.inspect 'praxis inspect'
    compare_praxis commands.inspect "$generic" inspect
    praxis_command commands.summary 'praxis summary'
    compare_praxis commands.summary "$generic" summary
    praxis_command commands.verify 'praxis --quiet verify'
    praxis_command commands.builtin 'praxis --quiet run list'
    compare_praxis commands.builtin "$generic" --quiet run list

    praxis_command runtime.help 'praxis help'
    "$generic" help >/dev/null
    praxis_command runtime.list 'praxis list'
    compare_praxis runtime.list "$generic" list
    praxis_command runtime.help-check 'praxis help check'
    "$generic" help check >/dev/null
    praxis_command runtime.plan 'praxis --json plan verify'
    "$generic" --json plan verify | jq -c '{command,scope,steps:[.steps[].command]}' > "$TMPDIR/praxis-actual"
    praxis_output runtime.plan "$TMPDIR/praxis-expected"
    cmp "$TMPDIR/praxis-expected" "$TMPDIR/praxis-actual"
    praxis_command runtime.doctor 'praxis doctor verify'
    "$generic" doctor verify >/dev/null
    praxis_command runtime.completions $'praxis completions fish\npraxis completions bash\npraxis completions zsh'
    for shell in fish bash zsh; do
      "$generic" completions "$shell" > "$TMPDIR/completion"
      "$shell" -n "$TMPDIR/completion"
    done

    prepare_project parameters
    praxis_command parameters.greet 'praxis greet River -gwelcome'
    compare_praxis parameters.greet "$generic" greet River -gwelcome
    praxis_command parameters.inspect 'praxis inspect -n2 --loud --destination=out/report.txt'
    compare_praxis parameters.inspect "$generic" inspect -n2 --loud --destination=out/report.txt
    praxis_command parameters.forward 'praxis forward --tag=outer -- --json "two words" ""'
    compare_praxis parameters.forward "$generic" forward --tag=outer -- --json 'two words' ""

    prepare_project scripts
    praxis_command scripts.source 'praxis source-script'
    compare_praxis scripts.source "$generic" source-script
    praxis_command scripts.generate 'praxis generate'
    compare_praxis scripts.generate "$generic" generate

    prepare_project workflow
    praxis_command workflow.publish $'praxis --yes --non-interactive --quiet publish\ncat .praxis-demo/receipt.txt'
    "$generic" --yes --non-interactive --quiet publish
    praxis_output workflow.receipt "$TMPDIR/praxis-expected"
    cmp "$TMPDIR/praxis-expected" .praxis-demo/receipt.txt
    praxis_command workflow.authenticate 'DEMO_TOKEN=test-only praxis --quiet authenticate'
    DEMO_TOKEN=test-only "$generic" --quiet authenticate

    prepare_project project
    praxis_command project.inspect 'praxis inspect'
    compare_praxis project.inspect "$generic" inspect
    praxis_command project.build 'praxis --quiet build'
    "$generic" --quiet build
    praxis_command project.check 'praxis --quiet check'
    "$generic" --quiet check
    praxis_command project.verify 'praxis --quiet verify'
    compare_praxis project.verify "$generic" --quiet verify
    rm -f result

    sort "$TMPDIR/validated-commands" -o "$TMPDIR/validated-commands"
    cmp "$TMPDIR/documented-commands" "$TMPDIR/validated-commands"
    cd "$root"

    jq -e '.praxisDocs.selectedChecks | all(test("^/nix/store/"))' "$values"
    ${setup.tasks.cli}/bin/praxis --quiet target --host ${lib.escapeShellArg setup.host.id} > "$TMPDIR/actual"
    printf '%s\n' ${lib.escapeShellArg setup.host.id} > "$TMPDIR/expected"
    cmp "$TMPDIR/expected" "$TMPDIR/actual"
    touch "$out"
  ''
