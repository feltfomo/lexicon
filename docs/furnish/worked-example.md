# A Paperkite studio configuration

This example manages five files for one fictional application on a host named `studio`. It keeps immutable editor settings as symlinks, publishes two writable files with policies chosen for their roles, and manages one system configuration under `/etc`.

The example remains Furnish-only. It uses a plain NixOS module and direct `lexicon.furnish.declarations`.

## Files in the example

[examples/furnish-studio](../../examples/furnish-studio/) contains:

```text
flake.nix
configuration.nix
furnish.nix
sources/editor.conf
sources/shortcuts.conf
sources/drafts.txt
sources/generated-index.conf
sources/service.conf
```

The source files are short fictional payloads. The complete flake wires the current public inputs and exposes a stable projection of `manifestData`.

### `configuration.nix`

<!-- source: ../../examples/furnish-studio/configuration.nix -->
```nix
{ lexicon, ... }:
{
  # bind the runtime before loading direct file declarations
  imports = [
    (lexicon.lib.furnishRuntime { })
    ./furnish.nix
  ];

  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

The user account exists in the evaluated configuration before an eventual activation. `boot.isContainer` keeps this repository example buildable without a hardware module; replace it when adapting the example to a real host.

### `furnish.nix`

The first two declarations are immutable user configuration:

<!-- excerpt: ../../examples/furnish-studio/furnish.nix -->
```nix
      {
        label = "paperkite editor settings";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/editor.conf";
        representation = "symlink";
        source = {
          kind = "path";
          value = ./sources/editor.conf;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
```

The next declaration is another symlink with the same authority and root. The manifest keeps entries in canonical identity order, not source-file order.

The drafts file chooses runtime edits when both sides diverge:

<!-- excerpt: ../../examples/furnish-studio/furnish.nix -->
```nix
        destination = ".local/share/paperkite/drafts.txt";
        representation = "writable";
        onConflict = "runtime-wins";
        source = {
          kind = "path";
          value = ./sources/drafts.txt;
        };
```

The generated index has the opposite responsibility:

<!-- excerpt: ../../examples/furnish-studio/furnish.nix -->
```nix
        destination = ".cache/paperkite/generated-index.conf";
        representation = "writable";
        onConflict = "source-wins";
        source = {
          kind = "path";
          value = ./sources/generated-index.conf;
        };
```

`source-wins` fits this generated artifact because runtime changes aren't authoritative. It would be a dangerous choice for drafts.

The system declaration uses `/etc` as its managed root and a canonical system identity:

<!-- excerpt: ../../examples/furnish-studio/furnish.nix -->
```nix
        label = "paperkite system service";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "system";
          identity = "x86_64-linux/studio";
        };
        managedRoot = "/etc";
        destination = "paperkite/service.conf";
        representation = "symlink";
```

Furnish can create the `paperkite` directory below `/etc`, but `/etc` itself must already exist.

## Evaluate the whole manifest

Run from the Lexicon root:

```sh
nix eval --impure --json --file examples/furnish-eval.nix studio.manifest
```

<!-- furnish-value: studio.manifest -->
```json
[{"authority":{"identity":"x86_64-linux/studio","scope":"system"},"canonical":"x86_64-linux/studio:/etc/paperkite/service.conf","destination":"/etc/paperkite/service.conf","namespace":"x86_64-linux/studio","onConflict":"error","provenance":{"declaration":"paperkite system service","source":"examples/furnish-studio/furnish.nix"},"representation":"symlink"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.cache/paperkite/generated-index.conf","destination":"/home/river/.cache/paperkite/generated-index.conf","namespace":"x86_64-linux/studio","onConflict":"source-wins","provenance":{"declaration":"paperkite generated index","source":"examples/furnish-studio/furnish.nix"},"representation":"writable"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.config/paperkite/editor.conf","destination":"/home/river/.config/paperkite/editor.conf","namespace":"x86_64-linux/studio","onConflict":"error","provenance":{"declaration":"paperkite editor settings","source":"examples/furnish-studio/furnish.nix"},"representation":"symlink"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.config/paperkite/shortcuts.conf","destination":"/home/river/.config/paperkite/shortcuts.conf","namespace":"x86_64-linux/studio","onConflict":"error","provenance":{"declaration":"paperkite shortcuts","source":"examples/furnish-studio/furnish.nix"},"representation":"symlink"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.local/share/paperkite/drafts.txt","destination":"/home/river/.local/share/paperkite/drafts.txt","namespace":"x86_64-linux/studio","onConflict":"runtime-wins","provenance":{"declaration":"paperkite drafts","source":"examples/furnish-studio/furnish.nix"},"representation":"writable"}]
```

The first entry is under `/etc` because canonical sorting uses the absolute destination. The remaining entries sort beneath `/home/river` by path. This ordering is deterministic and independent of declaration order.

Evaluation may materialize the five source artifacts in the Nix store. It doesn't create `/etc/paperkite`, write the user's home, or start the Paperkite application.

## Adapt the example

Before using the configuration on a host:

1. Replace the fictional host, user, paths, and source payloads.
2. Change the `system` and namespace together when targeting another platform or host identity.
3. Keep `runtime-wins` only where runtime edits are authoritative.
4. Keep `source-wins` only where discarding a two-sided runtime edit is acceptable.
5. Inspect the projected manifest after every destination or policy change.
6. Configure durable state before activation if the root can be wiped.
7. Check every destination for pre-existing files; Furnish won't adopt them from equality alone.

The example's flake also exposes `nixosConfigurations.studio`. Building its `lexicon.furnish.manifestPath` is safe; activation is intentionally outside this documentation exercise.

[Back to Furnish](README.md) · [Runtime and safety](runtime.md) · [Reference](reference.md)
