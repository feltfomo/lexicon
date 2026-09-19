{ pkgs, praxis }:
let
  argPrinter = pkgs.writeShellApplication {
    name = "praxis-generated-args";
    runtimeInputs = [ pkgs.jq ];
    text = ''jq -cn --args '$ARGS.positional' -- "$@"'';
  };
  echoArgs = [ "${argPrinter}/bin/praxis-generated-args" ];
  specs = {
    commands = {
      echo = echoArgs;
      praxis-word = echoArgs;
      typed = {
        command = echoArgs;
        args = [ { param = "mode"; } ];
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
          }
        ];
      };
      collision = {
        command = echoArgs;
        args = [ { param = "help"; } ];
        parameters = [
          {
            name = "help";
            short = "h";
            default = "child";
          }
        ];
      };
      local = {
        command = echoArgs;
        localFlake = true;
        args = [
          "target"
          "two words"
        ];
      };
      first.shell = "printf 'first\\n' >> trace";
      fail = {
        shell = "exit 23";
        description = "Preserve failure status";
      };
      later.shell = "touch should-not-run";
      cwd = {
        command = [ "${pkgs.coreutils}/bin/pwd" ];
        cwd = "nested";
      };
      env = {
        shell = ''printf '%s|%s' "$PRAXIS_VALUE" "$PRAXIS_INHERITED"'';
        env.PRAXIS_VALUE = "override";
      };
      shell.shell = ''printf '<%s>' "$@"'';
      unit = [ "${pkgs.coreutils}/bin/true" ];
      confirmed = {
        shell = "printf approved";
        confirm = true;
      };
    };
    tasks = {
      typed-raw = {
        parameters = [
          {
            name = "outer";
            default = "default";
          }
        ];
        steps = [ "again" ];
      };
      typed-chain = {
        parameters = [
          {
            name = "outer";
            default = "default";
          }
        ];
        steps = [
          {
            command = "typed-proxy";
            args = [ "--help=bound" ];
          }
        ];
      };
      typed-proxy = [ "collision" ];
      again = [ "echo" ];
      sequence = [
        "first"
        "first"
      ];
      stopped = [
        "first"
        "fail"
        "later"
      ];
      preflight = [
        "first"
        {
          command = "typed";
          args = [ "--mode=wrong" ];
        }
      ];
      forward = [
        "first"
        {
          command = "echo";
          forwardArgs = true;
        }
      ];
    };
  };
  base = specs // {
    inherit pkgs;
    root = ./fixtures;
    commands = specs.commands // {
      script = {
        script = ./fixtures/ci/fail.sh;
        interpreter = "${pkgs.bash}/bin/bash";
      };
      script-cwd = {
        script = ./fixtures/ci/fail.sh;
        interpreter = "${pkgs.bash}/bin/bash";
        cwd = "nested";
      };
    };
    checks = [ "unit" ];
  };
  plain = praxis base;
  wrapped = praxis (
    base
    // {
      name = "work";
      wrappers = true;
      perCommand = true;
    }
  );
  rooted = praxis (
    base
    // {
      name = "rooted";
      atRoot = true;
    }
  );
  checked = praxis {
    inherit pkgs;
    name = "checked";
    check = true;
  };
in
pkgs.runCommand "praxis-generated-cli"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.fish
      pkgs.gnugrep
      pkgs.jq
      pkgs.zsh
    ];
  }
  ''
    plain=${plain.package}
    wrapped=${wrapped.package}
    rooted=${rooted.package}
    checked=${checked.package}
    individual=${plain.commandPackages.echo}
    generated_check=${plain.checks.unit}
    work="$TMPDIR/praxis-generated-cli"
    mkdir -p "$work/nested" "$work/ci"
    printf '#!/usr/bin/env bash\nexec ${argPrinter}/bin/praxis-generated-args "$@"\n' > "$work/ci/fail.sh"

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

    dispatcher="$plain/bin/praxis"
    custom="$wrapped/bin/work"
    test "$(find "$plain/bin" -maxdepth 1 -mindepth 1 -printf '%f\n')" = praxis
    test -f "$wrapped/bin/echo"
    test -f "$wrapped/bin/again"
    test -f "$generated_check"
    cd "$work"
    expect_status 0 "$custom" --version
    test "$(cat stdout)" = 'work 1.0.0'
    expect_status 0 "$custom" help echo
    grep -F 'Usage: work echo' stdout
    expect_status 0 "$custom" list
    grep -F '[task]' stdout

    ${argPrinter}/bin/praxis-generated-args --help --json --quiet --complete -- "" \
      "two ' words" $'line\nbreak' '$(touch injected)' '界' > expected
    for command in \
      "$dispatcher echo" "$custom echo" "$wrapped/bin/echo" "$individual/bin/echo" \
      "$dispatcher again" "$wrapped/bin/again"; do
      read -r -a argv <<< "$command"
      expect_status 0 "''${argv[@]}" --help --json --quiet --complete -- "" \
        "two ' words" $'line\nbreak' '$(touch injected)' '界'
      cmp expected stdout
    done
    test ! -e injected

    expect_status 0 "$dispatcher" shell 'a b' "" --
    test "$(cat stdout)" = '<a b><><-->'
    expect_status 0 "$dispatcher" collision --help child-value
    jq -e '. == ["child-value"]' stdout
    expect_status 0 "$dispatcher" --quiet echo --json
    jq -e '. == ["--json"]' stdout
    expect_status 0 "$dispatcher" local raw --help
    jq -e '. == [".#target",".#two words","raw","--help"]' stdout
    expect_status 0 "$dispatcher" cwd
    test "$(cat stdout)" = "$work/nested"
    PRAXIS_INHERITED=kept PRAXIS_VALUE=ambient expect_status 0 "$dispatcher" env
    test "$(cat stdout)" = 'override|kept'
    expect_status 64 "$dispatcher" preflight
    test ! -e trace
    expect_status 0 "$dispatcher" sequence
    printf 'first\nfirst\n' > expected
    cmp expected trace
    rm -- trace
    expect_status 23 "$dispatcher" stopped
    test "$(cat trace)" = first
    test ! -e should-not-run
    expect_status 64 "$dispatcher" confirmed
    expect_status 0 "$dispatcher" --yes confirmed
    test "$(cat stdout)" = approved

    expect_status 0 "$dispatcher" script --help --json
    jq -e '. == ["--help","--json"]' stdout
    printf '#!/usr/bin/env bash\nprintf changed-without-rebuilding\n' > ci/fail.sh
    expect_status 0 "$dispatcher" script
    test "$(cat stdout)" = changed-without-rebuilding
    rm -- ci/fail.sh
    expect_status 66 "$dispatcher" script

    printf '{}\n' > flake.nix
    expect_status 0 "$rooted/bin/rooted" cwd
    test "$(cat stdout)" = "$work/nested"
    expect_status 0 "$checked/bin/checked" plan check -L --keep-going --show-trace --no-build
    jq -e '.steps[0].args == ["flake","check","-L","--keep-going","--show-trace","--no-build"]' stdout

    for prefix in praxis work; do
      package="$plain"
      test "$prefix" = work && package="$wrapped"
      binary="$package/bin/$prefix"
      for shell in fish bash zsh; do
        expect_status 0 "$binary" completions "$shell"
        "$shell" -n stdout
      done
      expect_status 0 "$binary" complete -- typed -m r
      test "$(cat stdout)" = release
    done
    touch "$out"
  ''
