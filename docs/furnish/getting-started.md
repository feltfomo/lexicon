# Evaluate your first managed file

This lesson evaluates a NixOS configuration containing one Furnish declaration. It shows the compiled destination and policy without activating the configuration or writing `/home/river`.

Run the checkout commands from the Lexicon root. If Nix syntax or flake commands are new, read [preparation](../preparation.md) first.

## The three files

The complete example is [examples/furnish](../../examples/furnish/). It contains:

- `flake.nix`, which pins Nixpkgs and Lexicon, builds a NixOS configuration, and projects stable fields from `lexicon.furnish.manifestData`;
- `files.nix`, which imports `lexicon.lib.furnishRuntime { }` and declares one file;
- `settings.conf`, the source artifact that the declaration retains.

Put all three files in the same directory.

### `flake.nix`

<!-- source: ../../examples/furnish/flake.nix -->
```nix
{
  description = "Minimal Furnish managed-file example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lexicon = {
      url = "github:feltfomo/lexicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      lexicon,
      ...
    }:
    let
      host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./files.nix { inherit lexicon; })
          {
            # container scaffolding keeps the example buildable without host hardware
            boot.isContainer = true;
            networking.hostName = "studio";
            users.users.river.isNormalUser = true;
            system.stateVersion = "26.05";
          }
        ];
      };
      # keep the first result stable by omitting store paths and integration metadata
      projectEntry = entry: {
        inherit (entry) onConflict representation;
        inherit (entry.filesystemIdentity) destination;
      };
    in
    {
      nixosConfigurations.demo = host;
      lib = {
        manifest = map projectEntry host.config.lexicon.furnish.manifestData;
        runtime = {
          enabled = host.config.lexicon.furnish.enable;
          ledgerPath = host.config.lexicon.furnish.ledgerPath;
          manifestAvailable = host.config.lexicon.furnish.manifestPath != null;
          serviceEnabled = host.config.systemd.services ? furnish;
        };
      };
    };
}
```

The beginner projection keeps only `destination`, `representation`, and `onConflict`. The full manifest remains available through the NixOS configuration; omitting its store paths and integration metadata keeps this first result stable and focused.

### `files.nix`

<!-- source: ../../examples/furnish/files.nix -->
```nix
{ lexicon }:
{
  # the bound runtime supplies pinned native executors
  imports = [ (lexicon.lib.furnishRuntime { }) ];

  lexicon.furnish = {
    enable = true;
    declarations = [
      # stable namespace, runtime authority, and traversal bounds are explicit in the raw interface
      {
        label = "paperkite settings";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/settings.conf";
        # immutable settings stay tied to the retained store artifact
        representation = "symlink";
        source = {
          kind = "path";
          value = ./settings.conf;
        };
      }
    ];
  };
}
```

This is the direct, low-level Furnish declaration contract. `label`, `filesystemNamespace`, `authority` with `scope` and `identity`, `managedRoot`, `destination`, `representation`, and `source` with `kind` and `value` are required. Together they state ledger identity, runtime authority, the traversal boundary, the destination, the lifecycle representation, and the source artifact.

`provenance` and `onConflict` are optional. This first declaration omits both: `onConflict` becomes `error`, and manifest provenance falls back to the required `label`. The focused and larger examples add provenance where source attribution improves diagnostics.

### `settings.conf`

<!-- source: ../../examples/furnish/settings.conf -->
```ini
theme=daylight
autosave=true
```

`river`, `studio`, and `paperkite` are fictional. The module declares the user so a later activation would have an account to use, but this lesson only evaluates the configuration.

## Evaluate the compiled declaration

From the Lexicon root, run:

```sh
nix eval --impure --json --file examples/furnish-eval.nix minimal.manifest
```

<!-- furnish-value: minimal.manifest -->
```json
[{"destination":"/home/river/.config/paperkite/settings.conf","onConflict":"error","representation":"symlink"}]
```

This first result answers three questions:

- the relative destination becomes `/home/river/.config/paperkite/settings.conf` beneath `managedRoot`;
- the selected representation is `symlink`;
- the omitted `onConflict` becomes `error`.

The full NixOS manifest still contains filesystem identity, authority, provenance, executor metadata, and the retained source target. Inspect those fields when the tasks in [usage](usage.md) or the [reference](reference.md) require them.

It doesn't prove that the running host has a `river` account or a free destination, and it doesn't create the destination.

Inspect the runtime-facing outputs too:

```sh
nix eval --impure --json --file examples/furnish-eval.nix minimal.runtime
```

<!-- furnish-value: minimal.runtime -->
```json
{"enabled":true,"ledgerPath":"/var/lib/furnish/applied-state.json","manifestAvailable":true,"serviceEnabled":true}
```

`manifestAvailable` and `serviceEnabled` describe the evaluated NixOS configuration. They don't mean the service ran.

## Make one predictable edit

In `files.nix`, change only the destination:

```nix
        destination = ".config/paperkite/preferences.conf";
```

Run the manifest evaluation again. The projected `destination` becomes `/home/river/.config/paperkite/preferences.conf`; `representation` remains `symlink`, and `onConflict` remains `error`.

## Use the example as an ordinary flake

Copy the three files into a new directory, then run commands from that directory. This route uses the declared GitHub inputs in `flake.nix`:

```sh
nix eval --json .#lib.manifest
```

On first use, Nix resolves the declared Lexicon and Nixpkgs inputs and writes `flake.lock` if one isn't present. That step needs access to the input sources unless they're already available locally. Later evaluations reuse the lock and local store data.

To build the actual desired-state document without activating the host, run:

```sh
nix build --no-link .#nixosConfigurations.demo.config.lexicon.furnish.manifestPath
```

`--no-link` avoids creating a `result` symlink. The build materializes the manifest and retained source artifact in the Nix store; it still doesn't write the declared destination.

For your own host, replace the fictional account, host name, source, destination, `system`, and `filesystemNamespace`. Keep the namespace stable after Furnish has applied state.

Next, choose a representation and conflict policy in [Furnish tasks](usage.md). Read [runtime and safety](runtime.md) before activation.

[Back to Furnish](README.md) · [Reference](reference.md)
