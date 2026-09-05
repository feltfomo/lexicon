{ pkgs, praxis }:
let
  compiled = praxis {
    inherit pkgs;
    commands = {
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
            name = "color";
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
              "import json,os,sys; print(json.dumps([sys.argv[1:], os.environ['PRAXIS_ARG_COLOR'], os.environ['PRAXIS_ARG_DESTINATION']]))"
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
      pkgs.bash
    ];
  }
  ''
    python3 ${./runtime.py} ${compiled.runner}/bin/praxis ${manifest} ${compiled.package}/bin ${modular.apps.praxis.program}
    touch "$out"
  ''
