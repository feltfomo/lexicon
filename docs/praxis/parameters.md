# Parameters and forwarding

Parameters give a command a small declared grammar. Start with only the fields the command needs, then add defaults, choices, environment sources, or short flags deliberately.

## Bind named and positional values

<!-- source: ../../examples/praxis-parameters/praxis.nix -->
```nix
{
  pkgs,
  root,
  ...
}:
{
  commands = {
    greet = {
      description = "Greet one person";
      parameters = [
        {
          name = "name";
          positional = true;
          required = true;
        }
        {
          name = "greeting";
          short = "g";
          choices = [
            "hello"
            "welcome"
          ];
          default = "hello";
        }
      ];
      # parameter references preserve argv boundaries without shell interpolation
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s, %s!\n"
        { param = "greeting"; }
        { param = "name"; }
      ];
      forwardArgs = false;
    };
    inspect = {
      description = "Show typed parameter values";
      parameters = [
        {
          name = "count";
          type = "int";
          short = "n";
          default = 1;
        }
        {
          name = "loud";
          type = "bool";
        }
        {
          name = "destination";
          type = "path";
          env = "PRAXIS_DESTINATION";
          default = "report.txt";
        }
      ];
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
        { param = "count"; }
        { param = "loud"; }
        { param = "destination"; }
      ];
      forwardArgs = false;
    };
    forward = {
      description = "Forward remaining argv without re-parsing it";
      # no forwardArgs = false here, so remaining argv reaches the command unparsed
      parameters = [
        {
          name = "tag";
          default = "outer";
        }
      ];
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
      ];
    };
  };
}
```

The `name` parameter is a required positional string. `greeting` is a named string with a short flag, two choices, and a default. `{ param = "name"; }` inserts the bound value as one argv item rather than interpolating it into shell source.

<!-- praxis-command: parameters.greet -->
```sh
praxis greet River -gwelcome
```

<!-- praxis-output: parameters.greet -->
```text
welcome, River!
```

## Add types and environment sources

Praxis accepts `string`, `int`, `bool`, and `path` parameter types. `inspect` uses the other three. A named boolean is a flag, and an absent boolean becomes `false`. Integer spelling is normalized before choice or condition comparison. A path is a non-empty runtime string; it is not copied into the Nix store.

<!-- praxis-command: parameters.inspect -->
```sh
praxis inspect -n2 --loud --destination=out/report.txt
```

<!-- praxis-output: parameters.inspect -->
```text
["2", "true", "out/report.txt"]
```

`env = "PRAXIS_DESTINATION";` provides an optional runtime source. An explicit command-line value wins over that environment value, which wins over the static default. Shell and script actions also receive every bound parameter as `PRAXIS_ARG_<NAME>`, with letters uppercased and `-` changed to `_`.

## Mark the forwarding boundary

A one-action command forwards remaining argv by default. When a command has declared parameters, a literal `--` ends Praxis parameter binding and is not passed to the child.

<!-- praxis-command: parameters.forward -->
```sh
praxis forward --tag=outer -- --json "two words" ""
```

<!-- praxis-output: parameters.forward -->
```text
["--json", "two words", ""]
```

The remaining rules prevent ambiguous routing:

- A sequence does not guess which action should receive remaining arguments.
- At most one action may set `forwardArgs = true`.
- `forwardArgs = false` rejects unexpected remaining arguments.
- Runner options such as `--quiet` and `--json` go before the command name.
- Child options, including `--help` or `--json`, go after the command name.
- A parameter intended for a referenced command can be placed in that reference's `args` list.

The [reference](reference.md#parameters) records ordering, duplicate, type, choice, short-flag, and group validation. Next, separate [script source from runtime roots](scripts-and-roots.md).
