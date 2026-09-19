# Scripts, roots, and working directories

Praxis has separate fields for build-time source and runtime directory policy. Treating them as interchangeable can make a command inspect the wrong checkout or look for a script in the wrong place.

## Check the complete example

<!-- source: ../../examples/praxis-scripts/praxis.nix -->
```nix
{
  pkgs,
  root,
  ...
}:
{
  # the installed command supplies the project source root

  atRoot = true;
  commands = {
    source-script = {
      description = "Run a source-backed script from another working directory";
      script = root + "/scripts/source.sh";
      interpreter = "${pkgs.bash}/bin/bash";
      cwd = "work";
    };
    generated-script = {
      description = "Run a script created earlier in the workflow";
      script = "generated/run.sh";
      interpreter = "${pkgs.bash}/bin/bash";
    };
    source-check = {
      description = "Check the source-backed script in a flake check";
      script = root + "/scripts/source.sh";
      interpreter = "${pkgs.bash}/bin/bash";
    };
  };
  tasks.generate = {
    description = "Create and then run a live relative script";
    steps = [
      {
        shell = ''
          ${pkgs.coreutils}/bin/mkdir -p generated
          printf '%s\n' "printf 'generated script\n'" > generated/run.sh
        '';
      }
      "generated-script"
    ];
  };
  # publish-time only: read when this declaration is compiled by
  # lexicon.lib.praxis, ignored by the installed command
  checks = [ "source-check" ];
}
```

The source-backed payload is intentionally small:

<!-- source: ../../examples/praxis-scripts/scripts/source.sh -->
```sh
printf 'source script directory: %s\n' "${PWD##*/}"
```

<!-- praxis-command: scripts.source -->
```sh
praxis source-script
```

<!-- praxis-output: scripts.source -->
```text
source script directory: work
```

The installed command supplies `root` as the project source selected from `flake.nix`. A Nix path such as `root + "/scripts/source.sh"` can be used by generated checks, but `root` does not mean “change to this directory at runtime.” The Nix path must remain inside that source root.

`atRoot = true;` is runtime policy. It walks upward from the caller until it finds a regular `flake.nix`, then uses that directory as the project root. The command-level `cwd = "work";` is resolved beneath that runtime root. The source-backed script remains anchored to the live project root even though the command runs in `work`.

## Resolve a generated script at runtime

A relative script string is resolved against the live runtime directory. Praxis does not require it to exist during Nix evaluation, so an earlier task action can create it.

<!-- praxis-command: scripts.generate -->
```sh
praxis generate
```

<!-- praxis-output: scripts.generate -->
```text
generated script
```

## Choose one root policy

Without `atRoot`, `discoverRoot`, or an absolute project `cwd`, Praxis uses the caller's directory.

- `atRoot = true` discovers a parent containing a regular `flake.nix`.
- `discoverRoot = "marker"` discovers a parent containing another clean relative marker.
- Project `cwd` is an absolute runtime directory.
- Command and action `cwd` values may be absolute or clean relative directories.
- `requireRoot = true` requires `root`, requires execution from the matching live project root, and checks that its regular `flake.nix` still matches the source used to build the command.

`atRoot` cannot be combined with `cwd` or `discoverRoot`. Project `cwd` and `discoverRoot` cannot both be selected. A project-scoped command must be invoked from its resolved project root or a descendant; a global command may enter an absolute project root from elsewhere. Full confinement and failure behavior are in the [reference](reference.md#roots-scope-and-scripts).

Next, add [prompts and workflow policy](interactions.md) where the workflow needs them.
