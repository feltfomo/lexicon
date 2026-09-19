# Give your everyday Nix work names

Most Nix work is a handful of long commands you retype constantly: rebuild a host, update the inputs, build an output, run the checks. Praxis lets you name them once in `flake.nix` and run them from anywhere in the project.

Everything on this page uses plain commands. Tasks, typed parameters beyond one host name, scripts, and interaction policy come later, and none of them are needed here.

## Start from the project flake

The complete project is `examples/praxis-everyday`. This is the flake that builds your machines, so it also knows their names.

<!-- source: ../../examples/praxis-everyday/flake.nix -->
```nix
{
  description = "Everyday Nix work with memorable names";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # the host names this configuration builds; the rebuild command binds one of them
      hosts = [
        "workstation"
        "server"
      ];
      packages.${system}.default = pkgs.writeText "praxis-everyday-result" "built safely\n";
      checks.${system}.artifact = pkgs.runCommandLocal "praxis-everyday-check" { } ''
        touch $out
      '';
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
```

In a real configuration `hosts` would be the names under `nixosConfigurations`, and `packages` and `checks` would be whatever that flake already publishes. Praxis only reads the `praxis` output.

## Declare the commands

This is `examples/praxis-everyday/praxis.nix`, the file the flake imports above.

<!-- source: ../../examples/praxis-everyday/praxis.nix -->
```nix
{
  pkgs,
  root,
  ...
}:
{
  atRoot = true;
  commands = {
    hosts = {
      description = "List the hosts this configuration builds";
      command = [
        "nix"
        "eval"
        "--json"
        ".#hosts"
      ];
    };
    target = {
      description = "Show the host name a rebuild would use";
      parameters = [
        {
          name = "host";
          description = "Which host to act on";
          positional = true;
          required = true;
          choices = [
            "workstation"
            "server"
          ];
        }
      ];
      # an argv command inserts the bound value here instead of reading an environment name
      command = [
        "${pkgs.coreutils}/bin/printf"
        "%s\n"
        { param = "host"; }
      ];
      forwardArgs = false;
    };
    rebuild = {
      description = "Switch one host to the current configuration";
      # this command changes the running system, so it asks before acting
      confirm = "Switch this machine to the current configuration?";
      parameters = [
        {
          # praxis rebuild server binds "server" here, because the parameter is positional
          name = "host";
          description = "Which host to switch";
          positional = true;
          required = true;
          # an unlisted name is refused during binding, before sudo runs
          choices = [
            "workstation"
            "server"
          ];
        }
      ];
      # the declared name reaches a shell action as PRAXIS_ARG_HOST, so this line
      # becomes sudo nixos-rebuild switch --flake ".#server"
      shell = ''sudo nixos-rebuild switch --flake ".#$PRAXIS_ARG_HOST"'';
      forwardArgs = false;
    };
    update = {
      description = "Update the flake inputs";
      command = [
        "nix"
        "flake"
        "update"
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
  };
}
```

Three things in that file are worth knowing before you copy it.

`command = [ ... ]` is argv, not a shell line. Each string stays one argument, which is why `"--json"` and `".#hosts"` are separate items. Nothing is word-split, so a path with a space in it survives.

`atRoot = true;` lets you run these commands from any subdirectory. Praxis walks up to the nearest `flake.nix` and runs there, so `praxis check` from `modules/desktop` still checks the whole project.

`description` is what you see when you list the project's commands.

## Run them

From the project directory, after `nix flake lock`:

<!-- praxis-command: everyday.hosts -->
```sh
praxis hosts
```

<!-- praxis-output: everyday.hosts -->
```text
["workstation","server"]
```

The names and descriptions are the project's own interface:

<!-- praxis-command: everyday.list -->
```sh
praxis list
```

<!-- praxis-output: everyday.list -->
```text
check	Run the project checks
hosts	List the hosts this configuration builds
rebuild	Switch one host to the current configuration
target	Show the host name a rebuild would use
update	Update the flake inputs
```

<!-- praxis-command: everyday.check -->
```sh
praxis --quiet check
```

## Rebuild one host by name

`praxis rebuild workstation` is the point of the `host` parameter. It is declared `positional` so the host name is written plainly after the command, `required` so a rebuild can never guess which machine you meant, and constrained by `choices` so an unknown name is refused during parameter binding instead of reaching `nixos-rebuild`.

### Where `$PRAXIS_ARG_HOST` comes from

The parameter's `name` is the only place the variable is declared. Praxis uppercases that name, replaces `-` with `_`, prefixes `PRAXIS_ARG_`, and passes it to the shell. Nothing else has to be wired up. Following one invocation end to end:

```sh
praxis rebuild server
```

1. `positional = true` means the bare word after the command name binds to `host`, so `host` is `"server"`.
2. `choices` is checked while the value is still structured data. `praxis rebuild laptop` stops here and nothing executes.
3. Praxis runs the shell action with `PRAXIS_ARG_HOST=server` in its environment.
4. Bash expands `".#$PRAXIS_ARG_HOST"` to `.#server`, so `nixos-rebuild` receives `--flake .#server`.

The `$` survives Nix evaluation because only `${...}` interpolates inside a `''...''` string; a bare `$NAME` is literal text, and Bash expands it at runtime.

So one parameter appears in three forms of the same name, and the transformation is mechanical:

| Declared in `praxis.nix` | Typed on the command line | Read by the shell action |
| --- | --- | --- |
| `name = "host";` | `praxis rebuild server` | `$PRAXIS_ARG_HOST` |
| `name = "message";` | `praxis commit "fix typo"` | `$PRAXIS_ARG_MESSAGE` |
| `name = "dry-run";` | `praxis deploy --dry-run` | `$PRAXIS_ARG_DRY_RUN` |

Without `positional = true`, a parameter is supplied as `--host=server` or `--host server`; positional only lets you drop that prefix. A `bool` parameter is a flag whose presence gives `true` and whose absence gives `false`.

### The argv form does not use the variable

`$PRAXIS_ARG_*` exists for `shell` and `script` actions. An argv command takes `{ param = "host"; }` in the position where the value belongs, and Praxis inserts the bound value as exactly one argument — no shell, no quoting, no variable. That is the difference between `target` and `rebuild` in the file above, and `target` binds the same parameter without changing anything:

<!-- praxis-command: everyday.target -->
```sh
praxis target server
```

<!-- praxis-output: everyday.target -->
```text
server
```

Prefer the argv form. `rebuild` needs `shell` only because `.#server` has to be assembled from a literal and a bound value, which argv cannot do inside a single argument.

Adding a host is a one-line edit: add its name to `hosts` and to both `choices` lists. Praxis reevaluates the declaration on every invocation, so the new name works immediately without reinstalling anything.

Running `praxis rebuild` switches the machine it runs on, so the documentation tests check its declaration, parameters, and help output rather than executing it:

<!-- praxis-command: everyday.help-rebuild -->
```sh
praxis help rebuild
```

The `confirm` message appears before the switch happens. `--yes` accepts it for unattended use; see [interactions and policy](interactions.md).

## Two commands worth adding next

`update` above runs `nix flake update` and needs no parameters. Two more that fit the same shape:

```nix
    build = {
      description = "Build one host without activating it";
      parameters = [
        {
          name = "host";
          positional = true;
          required = true;
        }
      ];
      shell = ''nix build ".#nixosConfigurations.$PRAXIS_ARG_HOST.config.system.build.toplevel"'';
      forwardArgs = false;
    };
    fmt = {
      description = "Format the whole repository";
      command = [
        "nix"
        "fmt"
      ];
    };
```

Both belong in the `commands` set of `praxis.nix`, beside `rebuild`. `build` is the safe rehearsal for `rebuild`: it produces the same system closure without touching the running machine.

Once several commands are always run together, give the sequence a name with a [task](commands-and-tasks.md), which is the next page.
