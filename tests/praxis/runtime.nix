{ pkgs, praxis }:
let
  argPrinter = pkgs.writeShellApplication {
    name = "praxis-args";
    runtimeInputs = [ pkgs.jq ];
    text = ''jq -cn --args '$ARGS.positional' -- "$@"'';
  };
  echoArgs = [ "${argPrinter}/bin/praxis-args" ];
  compiled = praxis {
    inherit pkgs;
    commands = {
      tool = {
        description = "Forward arguments without a parameter inventory";
        steps = [
          {
            exec = echoArgs;
            label = "Echo literal arguments";
          }
        ];
      };
      strict-tool.steps = [
        {
          exec = echoArgs;
          forwardArgs = false;
        }
      ];
      bare.steps = [ { exec = [ "printf" ]; } ];
      script-tool.steps = [
        {
          script = "scripts/tool.sh";
          interpreter = "${pkgs.bash}/bin/bash";
        }
      ];
      tool-alias.steps = [ { command = "tool"; } ];
      choice-alias.steps = [ { command = "choose"; } ];
      list = "printf declared-list";
      choose = {
        description = "Choose a build mode";
        category = "build";
        aliases = [ "ch" ];
        examples = [ "praxis choose -m release" ];
        parameters = [
          {
            name = "mode";
            short = "m";
            choices = [
              "debug"
              "release"
              "two words"
            ];
            default = "debug";
            env = "PRAXIS_TEST_MODE";
          }
        ];
        steps = [
          {
            run = "printf '%s' \"$PRAXIS_ARG_MODE\"";
            label = "Print mode";
          }
        ];
      };
      hidden = {
        hidden = true;
        steps = [ "true" ];
      };
      old = {
        deprecated = "Use choose instead";
        steps = [ "true" ];
      };
      acknowledgement.steps = [
        {
          prompt = {
            type = "acknowledge";
            message = "Approve deletion";
            acknowledgement = "DELETE";
          };
        }
        "touch approved"
      ];
      selection.steps = [
        {
          prompt = {
            type = "select";
            name = "target";
            message = "Choose target";
            choices = [
              "local"
              "remote"
            ];
            default = "local";
          };
        }
        { run = "printf '%s' \"$PRAXIS_PROMPT_TARGET\""; }
        {
          run = "touch remote";
          when.env.PRAXIS_PROMPT_TARGET = "remote";
        }
      ];
      confirm-step.steps = [
        { prompt.message = "Continue now?"; }
        "printf approved"
      ];
      conditions = {
        parameters = [
          {
            name = "enabled";
            type = "bool";
          }
        ];
        steps = [
          {
            run = "printf parameter";
            when.parameters.enabled = true;
          }
          {
            run = "printf platform";
            when.platforms = [ "not-a-real-platform" ];
          }
          {
            run = "printf environment";
            when.env.PRAXIS_TEST_ENV = "match";
          }
        ];
      };
      groups = {
        parameters = [
          { name = "one"; }
          { name = "two"; }
          { name = "three"; }
        ];
        parameterGroups = [
          {
            type = "exclusive";
            parameters = [
              "one"
              "two"
            ];
          }
          {
            type = "together";
            parameters = [
              "two"
              "three"
            ];
          }
        ];
        steps = [ "printf grouped" ];
      };
      secret = {
        parameters = [
          {
            name = "token";
            sensitive = true;
            required = true;
            env = "PRAXIS_TEST_TOKEN";
          }
        ];
        steps = [
          {
            run = "test -n \"$PRAXIS_ARG_TOKEN\"; printf '%s' \"$PRAXIS_ARG_TOKEN\"; printf '%s' \"$PRAXIS_ARG_TOKEN\" >&2; touch secret-used";
            label = "Use runtime credential";
          }
        ];
      };
      timeout = {
        runtimeInputs = [ pkgs.coreutils ];
        lock = "praxis-timeout-test";
        steps = [
          {
            run = "trap '' TERM; sleep 60 & echo $! > timeout-child; wait";
            timeout = 1;
            label = "Timed child";
          }
          "touch after-timeout"
        ];
      };
      command-timeout = {
        runtimeInputs = [ pkgs.coreutils ];
        timeout = 1;
        steps = [
          "sleep 0.6"
          "sleep 0.6"
          "touch after-timeout"
        ];
      };
      nested-timeout = {
        runtimeInputs = [ pkgs.coreutils ];
        steps = [
          {
            command = "command-timeout";
            timeout = 1;
          }
        ];
      };
      notify = {
        ui.notifications = {
          desktop = true;
          command = [
            "${pkgs.bash}/bin/bash"
            "${./fixtures/notify.sh}"
            "${pkgs.jq}/bin/jq"
          ];
        };
        steps = [ "true" ];
      };
      notify-fail = {
        ui.notifications = {
          desktop = true;
          command = [
            "${pkgs.bash}/bin/bash"
            "${./fixtures/notify.sh}"
            "${pkgs.jq}/bin/jq"
          ];
        };
        steps = [ "exit 23" ];
      };
      prompt-timeout = {
        timeout = 1;
        steps = [ { prompt.message = "Waiting for confirmation"; } ];
      };
      first = "printf 'first\\n' >> trace";
      last = "printf 'last\\n' >> trace";
      sequence = [
        { command = "first"; }
        { command = "first"; }
        { command = "last"; }
        { command = "last"; }
      ];
      literal = {
        parameters = [
          {
            name = "word";
            positional = true;
            required = true;
          }
          {
            name = "count";
            type = "int";
            default = 4;
          }
          {
            name = "colorize";
            type = "bool";
            default = false;
          }
          {
            name = "destination";
            type = "path";
            default = "somewhere";
          }
        ];
        steps = [
          {
            exec = [
              "${pkgs.bash}/bin/bash"
              "${./fixtures/literal.sh}"
              { param = "word"; }
              { param = "count"; }
            ];
            forwardArgs = true;
          }
        ];
      };
      forwarding = [
        {
          command = "literal";
          args = [ "nested literal" ];
          forwardArgs = true;
        }
      ];
      preflight = [
        { command = "first"; }
        { command = "literal"; }
      ];
      confirm = [
        {
          run = "printf accepted";
          confirm = "Continue?";
        }
      ];
      interactive = [
        {
          run = "read -r value; printf 'received:%s\\n' \"$value\"";
          interactive = true;
        }
      ];
      cancel = {
        runtimeInputs = [ pkgs.coreutils ];
        lock = "praxis-runtime-test";
        steps = [
          "trap '' TERM; sleep 60 & echo $! > descendant; printf ready > ready; wait"
          "touch should-not-run"
        ];
      };
      locked = {
        lock = "praxis-runtime-test";
        steps = [ "printf unlocked" ];
      };
      plain = [
        {
          run = "printf data; printf 'child error\\n' >&2";
          label = "line\nlabel";
        }
      ];
      cwd.steps = [
        {
          run = "pwd -P";
          cwd = "nested";
        }
      ];
      scoped = {
        scope = "project";
        steps = [ "pwd -P" ];
      };
      fail = [
        "exit 23"
        "touch should-not-run"
      ];
    };
  };
  manifest = pkgs.writeText "praxis-test.json" (builtins.toJSON compiled.manifest);
  modular =
    (import ./fixtures/modular/flake-module.nix {
      inputs.lexicon.lib.praxis = praxis;
    }).perSystem
      { inherit pkgs; };
in
pkgs.runCommandLocal "praxis-runtime-tests"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.expect
      pkgs.fish
      pkgs.gnugrep
      pkgs.jq
      pkgs.zsh
    ];
  }
  ''
    runner=${compiled.runner}/bin/praxis
    manifest=${manifest}
    dispatcher=${compiled.package}/bin/praxis
    modular=${modular.apps.praxis.program}
    work="$TMPDIR/praxis-runtime"
    mkdir -p "$work/nested" "$work/scripts"
    printf '{}\n' > "$work/flake.nix"
    printf '#!/usr/bin/env bash\nexec ${argPrinter}/bin/praxis-args "$@"\n' > "$work/scripts/tool.sh"

    expect_status() {
      expected="$1"
      shift
      status=0
      "$@" > "$work/stdout" 2> "$work/stderr" || status=$?
      test "$status" -eq "$expected" || {
        cat "$work/stdout" "$work/stderr" >&2
        return 1
      }
    }
    invoke() {
      expect_status "$1" "$runner" --manifest "$manifest" "''${@:2}"
    }

    cd "$work"
    jq '.version = 999' "$manifest" > unsupported-manifest.json
    expect_status 65 "$runner" --manifest unsupported-manifest.json list
    grep -F 'unsupported manifest version 999' stderr
    printf '{' > malformed-manifest.json
    expect_status 65 "$runner" --manifest malformed-manifest.json list
    grep -F 'invalid manifest:' stderr
    rm -- unsupported-manifest.json malformed-manifest.json

    ${argPrinter}/bin/praxis-args build --json --quiet "two ' words" \
      '$(touch injected)' "" '界' > expected
    invoke 0 tool build --json --quiet "two ' words" '$(touch injected)' "" '界'
    cmp expected stdout
    invoke 0 script-tool build --json --quiet "two ' words" '$(touch injected)' "" '界'
    cmp expected stdout
    test ! -e injected
    invoke 0 bare '<%s>' 'a b' "" '$(touch injected)'
    test "$(cat stdout)" = '<a b><><$(touch injected)>'
    invoke 64 strict-tool stray
    invoke 0 choice-alias --mode=release
    test "$(cat stdout)" = release
    invoke 0 run list
    test "$(cat stdout)" = declared-list
    invoke 0 list
    grep -F $'list\t' stdout
    invoke 0 help tool
    grep -F 'Usage: praxis tool' stdout
    invoke 0 plan sequence
    jq -e '[.steps[].command] == ["first","first","last","last"]' stdout
    test ! -e trace
    invoke 0 sequence
    printf 'first\nfirst\nlast\nlast\n' > expected
    cmp expected trace
    rm -- trace
    invoke 64 run preflight
    test ! -e trace
    invoke 23 run fail
    test ! -e should-not-run
    invoke 0 run literal "two ' words \$(touch injected)" --count=-7 --colorize \
      '--destination=a b' -- "" --flag
    jq -e ".[0][1:] == [\"-7\",\"\",\"--flag\"] and .[1:] == [\"true\",\"a b\"]" stdout
    test ! -e injected
    invoke 64 run confirm
    invoke 0 --yes run confirm
    test "$(cat stdout)" = accepted
    invoke 64 --non-interactive run interactive
    invoke 0 --plain run plain
    test "$(cat stdout)" = data
    grep -F 'child error' stderr
    invoke 0 completions fish --wrappers
    fish -n stdout
    invoke 0 completions bash --wrappers
    bash -n stdout
    invoke 0 completions zsh --wrappers
    zsh -n stdout
    invoke 0 doctor choose
    grep -F 'ok ' stdout
    invoke 0 run choose
    test "$(cat stdout)" = debug
    PRAXIS_TEST_MODE='two words' invoke 0 run choose
    test "$(cat stdout)" = 'two words'
    PRAXIS_TEST_MODE=release invoke 0 run choose --mode=debug
    test "$(cat stdout)" = debug
    invoke 64 run choose --mode=nope
    PRAXIS_TEST_MODE=nope invoke 64 run choose
    invoke 0 list
    ! grep -F $'hidden\t' stdout
    invoke 0 list --all
    grep -F $'hidden\t' stdout
    invoke 0 run old
    grep -F deprecated stderr
    invoke 0 show choose
    grep -F 'Choose a build mode' stdout
    grep -F 'build' stdout
    invoke 64 run groups --one=a --two=b
    invoke 64 run groups --two=b
    invoke 0 run groups --two=b --three=c
    test "$(cat stdout)" = grouped
    invoke 0 run conditions
    test ! -s stdout
    invoke 0 run conditions --enabled
    test "$(cat stdout)" = parameter
    PRAXIS_TEST_ENV=match invoke 0 run conditions
    test "$(cat stdout)" = environment
    invoke 0 --non-interactive run selection
    test "$(cat stdout)" = local
    test ! -e remote
    invoke 64 --non-interactive run acknowledgement
    invoke 64 --non-interactive run confirm-step
    invoke 0 --yes --non-interactive run confirm-step
    test "$(cat stdout)" = approved
    secret='visible-nowhere-42'
    PRAXIS_TEST_TOKEN="$secret" invoke 0 plan secret
    ! grep -F "$secret" stdout
    grep -F '<sensitive>' stdout
    invoke 64 run secret --token="$secret"
    invoke 64 --non-interactive run secret
    PRAXIS_TEST_TOKEN="$secret" invoke 0 --verbose run secret
    ! grep -F "$secret" stdout stderr
    test -e secret-used
    rm -- secret-used
    invoke 124 run timeout
    test ! -e after-timeout
    child=$(cat timeout-child)
    ! kill -0 "$child" 2>/dev/null
    rm -- timeout-child
    invoke 124 run command-timeout
    test ! -e after-timeout
    invoke 124 run nested-timeout
    test ! -e after-timeout
    PRAXIS_TEST_TOKEN="$secret" invoke 23 --json run notify-fail
    jq -s -e '.[-1].event == "error" and .[-1].code == 23' stdout
    jq -e '.[0][-1] == "notify-fail failed" and .[1] == false' notification
    rm -- notification
    invoke 0 --notify=never run notify
    test ! -e notification
    invoke 0 --json run choose
    jq -s -e '.[-1].event == "finished" and .[-1].success == true' stdout
    invoke 23 --json run fail
    jq -s -e '.[-1].event == "error" and .[-1].code == 23' stdout
    invoke 0 complete -- run choose --mode=r
    test "$(cat stdout)" = '--mode=release'
    invoke 0 complete -- --output j
    test "$(cat stdout)" = json
    invoke 0 run cwd
    test "$(cat stdout)" = "$work/nested"
    invoke 0 run scoped
    test "$(cat stdout)" = "$work"
    invoke 0 --json plan scoped
    jq -e '.scope == "project" and (.cwd | length > 0)' stdout
    rmdir nested
    invoke 1 doctor cwd
    mkdir nested

    "$runner" --manifest "$manifest" run cancel > cancel.stdout 2> cancel.stderr &
    cancel_pid=$!
    for attempt in $(seq 1 100); do
      test -e ready && break
      sleep 0.02
    done
    test -e ready
    invoke 75 run locked
    kill -TERM "$cancel_pid"
    cancel_status=0
    wait "$cancel_pid" || cancel_status=$?
    test "$cancel_status" -eq 143
    descendant=$(cat descendant)
    ! kill -0 "$descendant" 2>/dev/null
    test ! -e should-not-run
    invoke 0 run locked
    test "$(cat stdout)" = unlocked
    rm -- ready descendant cancel.stdout cancel.stderr

    export RUNNER="$runner" MANIFEST="$manifest" WORK="$work"
    expect -c 'set timeout 10; spawn -noecho $env(RUNNER) --manifest $env(MANIFEST) run interactive; expect "running"; send "terminal\r"; expect "received:terminal"; expect eof; catch wait result; exit [lindex $result 3]'
    expect -c 'set timeout 10; spawn -noecho $env(RUNNER) --manifest $env(MANIFEST) --yes run acknowledgement; expect "type DELETE"; send "DELETE\r"; expect eof; catch wait result; exit [lindex $result 3]'
    test -e approved
    rm -- approved
    expect -c 'set timeout 10; spawn -noecho $env(RUNNER) --manifest $env(MANIFEST) run selection; expect "Choose target"; send "2\r"; expect eof; catch wait result; exit [lindex $result 3]'
    test -e remote
    expect -c 'set timeout 10; spawn -noecho $env(RUNNER) --manifest $env(MANIFEST) run prompt-timeout; expect "Waiting for confirmation"; expect eof; catch wait result; if {[lindex $result 3] != 124} {exit 1}'
    expect -c 'set timeout 10; spawn -noecho $env(RUNNER) --manifest $env(MANIFEST) run confirm-step; expect "Continue now?"; send "\003"; expect eof; catch wait result; if {[lindex $result 3] != 130} {exit 1}'

    PRAXIS_TEST_TOKEN=hidden invoke 0 run notify
    jq -e '.[0] == ["Praxis","notify succeeded"] and .[1] == false' notification
    rm -- notification
    invoke 0 --notify=never run notify
    test ! -e notification

    cd nested
    "$modular" plan gate > plan.json
    jq -e '[.steps[].command] == ["fmt","test"]' plan.json
    mkdir -p ../scripts
    printf '#!/usr/bin/env bash\nprintf "<%%s>" "$@"\n' > ../scripts/test.sh
    "$modular" run test -- 'a b' "" > actual
    test "$(cat actual)" = '<--><a b><>'

    touch "$out"
  ''
