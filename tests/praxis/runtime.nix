{ pkgs, praxis }:
let
  compiled = praxis {
    inherit pkgs;
    commands = {
      choose = {
        description = "Choose a build mode";
        category = "build";
        aliases = [ "ch" ];
        examples = [ "praxis run choose -m release" ];
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
            "${pkgs.python3}/bin/python3"
            "notify.py"
          ];
        };
        steps = [ "true" ];
      };
      notify-fail = {
        ui.notifications = {
          desktop = true;
          command = [
            "${pkgs.python3}/bin/python3"
            "notify.py"
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
              "${pkgs.python3}/bin/python3"
              "-c"
              "import json,os,sys; print(json.dumps([sys.argv[1:], os.environ['PRAXIS_ARG_COLORIZE'], os.environ['PRAXIS_ARG_DESTINATION']]))"
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
      pkgs.python3
      pkgs.fish
      pkgs.zsh
      pkgs.bash
    ];
  }
  ''
    python3 ${./runtime.py} ${compiled.runner}/bin/praxis ${manifest} ${compiled.package}/bin ${modular.apps.praxis.program}
    python3 ${./interaction.py} ${compiled.runner}/bin/praxis ${manifest} ${compiled.package}/bin ${./snapshots.json}
    touch "$out"
  ''
