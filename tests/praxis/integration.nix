{ pkgs, praxis }:
let
  inherit (pkgs) lib;
  script = "ci/record 'args'.sh";
  arguments = [
    "a b"
    "'quote'"
    "$(touch injected)"
    ""
    "-n"
    "line\nbreak"
    "a\\b"
  ];
  envValue = "value ' $(touch env-injected)\nnext";
  compiled = praxis {
    inherit pkgs;
    root = ./fixtures;
    requireRoot = true;
    commands = {
      ordered = {
        runtimeInputs = [ pkgs.hello ];
        env.PRAXIS_VALUE = envValue;
        steps = [
          {
            run = "printf 'first\\n' >> trace; printf '%s' \"$PRAXIS_VALUE\" > env.actual; cd ci";
            label = "prepare";
          }
          {
            inherit script;
            interpreter = "${pkgs.bash}/bin/bash";
            args = arguments;
          }
          { run = "printf 'last\\n' >> trace; hello --greeting='runtime input'"; }
        ];
      };
      gate.steps = [
        { run = "printf 'first\\n' >> trace"; }
        {
          inherit script;
          interpreter = "${pkgs.bash}/bin/bash";
          args = arguments;
        }
        {
          run = "exit 23; touch after-failure";
          label = "intentional failure";
        }
        { run = "touch later-step"; }
      ];
      strict.steps = [
        { run = "false; touch after-failure"; }
        { run = "touch later-step"; }
      ];
      pipeline.steps = [ { run = "false | true; touch after-failure"; } ];
      script-failure.steps = [
        {
          script = "ci/fail.sh";
          interpreter = "${pkgs.bash}/bin/bash";
        }
        { run = "touch later-step"; }
      ];
      direct = {
        runtimeInputs = [ pkgs.bash ];
        steps = [
          {
            inherit script;
            args = arguments;
          }
        ];
      };
      missing.steps = [ { script = "ci/missing.sh"; } ];
      escape.steps = [
        {
          script = "ci/escape.sh";
          interpreter = "${pkgs.bash}/bin/bash";
        }
      ];
      inside.steps = [
        {
          script = "ci/inside.sh";
          interpreter = "${pkgs.bash}/bin/bash";
          args = arguments;
        }
      ];
      newline.steps = [
        {
          script = "ci/line\n";
          interpreter = "${pkgs.bash}/bin/bash";
          args = arguments;
        }
      ];
      generated.steps = [
        { run = "printf 'printf generated > generated.actual\\n' > ci/generated.sh"; }
        {
          script = "ci/generated.sh";
          interpreter = "${pkgs.bash}/bin/bash";
        }
      ];
      inline-args.steps = [
        {
          run = "printf '%s\\0' \"$@\" > inline-args.actual";
          args = arguments;
        }
      ];
      marker-change.steps = [
        { run = "printf '\\n' >> flake.nix"; }
        { run = "touch after-marker-change"; }
      ];
    };
  };
  exe = name: compiled.apps.${name}.program;
in
pkgs.runCommandLocal "praxis-integration"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.diffutils
    ];
  }
  ''
    checkout=${lib.escapeShellArg "checkout 'live'\n"}
    mkdir "$checkout"
    cp -R ${./fixtures}/. "$checkout/"
    chmod -R u+w "$checkout"
    cd "$checkout"
    printf '%s\0' ${lib.escapeShellArgs arguments} > args.expected
    printf '%s' ${lib.escapeShellArg envValue} > env.expected

    expect_status() {
      local expected="$1" status=0
      shift
      "$@" > stdout 2> stderr || status=$?
      if [[ "$status" -ne "$expected" ]]; then
        cat stdout stderr >&2
        printf 'expected exit %s, got %s\n' "$expected" "$status" >&2
        exit 1
      fi
    }

    expect_status 0 ${exe "ordered"}
    printf 'first\nscript\nlast\n' > trace.expected
    cmp trace.expected trace
    cmp args.expected args.actual
    cmp env.expected env.actual
    grep -F 'fixture stdout' stdout
    grep -F 'fixture stderr' stderr
    grep -F 'runtime input' stdout
    test ! -e injected
    test ! -e env-injected

    rm -- trace
    expect_status 23 ${exe "gate"}
    printf 'first\nscript\n' > trace.expected
    cmp trace.expected trace
    grep -F 'failed [3/4] intentional failure' stderr
    grep -F 'failed (exit 23)' stderr
    test ! -e after-failure
    test ! -e later-step
    expect_status 1 ${exe "strict"}
    test ! -e after-failure
    test ! -e later-step
    expect_status 1 ${exe "pipeline"}
    test ! -e after-failure
    expect_status 37 ${exe "script-failure"}
    grep -F 'script failure' stderr
    grep -F 'exit 37' stderr
    test ! -e later-step

    expect_status 126 ${exe "direct"}
    grep -F 'not executable' stderr
    chmod u+x ${lib.escapeShellArg script}
    patchShebangs ${lib.escapeShellArg script}
    expect_status 0 ${exe "direct"}
    cmp args.expected args.actual
    cp -- ${lib.escapeShellArg script} ${lib.escapeShellArg "ci/line\n"}
    expect_status 0 ${exe "newline"}
    cmp args.expected args.actual
    ln -s -- ${lib.escapeShellArg "record 'args'.sh"} ci/inside.sh
    expect_status 0 ${exe "inside"}
    cmp args.expected args.actual
    expect_status 0 ${exe "inline-args"}
    cmp args.expected inline-args.actual
    test ! -e injected
    expect_status 0 ${exe "generated"}
    test "$(< generated.actual)" = generated
    expect_status 66 ${exe "missing"}
    grep -F 'script not found' stderr

    printf 'touch escaped\n' > ../outside.sh
    ln -s "$PWD/../outside.sh" ci/escape.sh
    expect_status 65 ${exe "escape"}
    grep -F 'escapes its live source directory' stderr
    test ! -e escaped
    expect_status 64 ${exe "ordered"} unexpected
    grep -F 'unexpected argument' stderr
    cd ci
    expect_status 64 ${exe "ordered"}
    grep -F 'project root containing flake.nix' stderr
    cd ..
    expect_status 0 ${exe "marker-change"}
    test -e after-marker-change
    expect_status 64 ${exe "ordered"}
    grep -F 'different flake.nix' stderr
    cp ${./fixtures/flake.nix} flake.nix

    store_status=0
    (cd ${./fixtures}; ${exe "ordered"}) > store.stdout 2> store.stderr || store_status=$?
    test "$store_status" -eq 64
    grep -F 'live project root' store.stderr
    printf 'praxis runtime checks passed\n'
    touch "$out"
  ''
