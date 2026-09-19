# Commands and tasks

A command performs one useful action. Start with direct commands; add a task only when ordered composition improves the project interface.

<!-- source: ../../examples/praxis-commands/praxis.nix -->
```nix
{
  pkgs,
  root,
  ...
}:
{
  atRoot = true;
  commands = {
    inspect = {
      description = "Evaluate the project status";
      command = [
        "nix"
        "eval"
        "--json"
        ".#status"
      ];
    };
    arguments = {
      description = "Show forwarded argument boundaries";
      # jq makes empty and space-containing arguments visible
      command = [
        "${pkgs.jq}/bin/jq"
        "-cn"
        "--args"
        "$ARGS.positional"
        "--"
      ];
    };
    check = {
      description = "Run the project checks";
      command = [
        "nix"
        "flake"
        "check"
        "-L"
      ];
    };
    summary = {
      description = "Label the evaluated status";
      shell = "printf 'status='; nix eval --json .#status";
    };
    list = {
      description = "A command whose name matches a built-in";
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s\n"
        "declared list command"
      ];
    };
  };
  tasks.verify = {
    description = "Inspect the project and then run its checks";
    steps = [
      "inspect"
      "check"
    ];
  };
}
```

`command = [ ... ]` is literal argv. Praxis preserves each item as one argument and forwards trailing arguments by default for a one-action command.

<!-- praxis-command: commands.inspect -->
```sh
praxis inspect
```

<!-- praxis-output: commands.inspect -->
```text
"ready"
```

Use `shell` only when expansion, a pipeline, or redirection is part of the intended action:

<!-- praxis-command: commands.summary -->
```sh
praxis summary
```

<!-- praxis-output: commands.summary -->
```text
status="ready"
```

A string in `tasks.<name>.steps` is a command reference, not shell source. Tasks preserve order and stop after the first failure.

<!-- praxis-command: commands.verify -->
```sh
praxis --quiet verify
```

<!-- praxis-output: commands.verify -->
```text
"ready"
```

Unknown references and reference cycles are declaration errors reported before execution. A sequence never guesses which action should receive trailing arguments; at most one action may opt in with `forwardArgs = true`.

`list` is a built-in name. Invoke the authored collision explicitly:

<!-- praxis-command: commands.builtin -->
```sh
praxis --quiet run list
```

<!-- praxis-output: commands.builtin -->
```text
declared list command
```

Next, add [typed parameters only where interpretation is useful](parameters.md).
