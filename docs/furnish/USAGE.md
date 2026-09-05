# Using Furnish

## Manage a writable file in NixOS

The runtime module supplies the coordinator and built-in executors. It can be
used without Program or Den:

```nix
{ inputs, ... }:
{
  imports = [ (inputs.lexicon.lib.furnishRuntime { }) ];

  users.users.alice = {
    isNormalUser = true;
    home = "/home/alice";
  };

  lexicon.furnish = {
    enable = true;
    state = {
      path = "/var/lib/furnish";
      durability = "durable";
      requiresMountsFor = [ "/var/lib" ];
    };
    declarations = [ {
      label = "terminal configuration";
      filesystemNamespace = "x86_64-linux/workstation";
      authority = { scope = "user"; identity = "alice"; };
      managedRoot = "/home/alice";
      destination = ".config/terminal/config";
      representation = "writable";
      source = { kind = "path"; value = ./terminal-config; };
      onConflict = "runtime-wins";
      provenance.source = "configuration/terminal.nix";
    } ];
  };
}
```

Pass `inputs` through your NixOS `specialArgs`, and provide the referenced
`terminal-config` source file. The example assumes `/var/lib` persists across
boots. Furnish does not make it persistent: `durability` describes your actual
storage layout. Use `ephemeral` if the ledger will be lost on reboot.

This declaration has already chosen its user and host namespace, so it has no
Ownerships claim fields. If you add ownership-tagged declarations, configure
an enabled Ownerships provider rather than sending those claims to the default
disabled provider. See [runtime integration](runtime-integration.md).

## Decide who owns changes

A `symlink` keeps content in the store; an application cannot edit that target.
A `writable` file contains real runtime content. Its conflict policy decides
what to do when it diverges from the applied baseline:

| Policy | Use when |
| --- | --- |
| `error` | You want a conflict reported before replacement |
| `source-wins` | The declaration is authoritative, such as a generated theme |
| `runtime-wins` | The application or user owns runtime edits |

The ledger records what was applied. It does not identify who made later edits.
Choose a policy based on the file's ownership, not on an assumption that all
runtime changes are disposable.

## Destinations and collisions

A destination can be absolute or relative to `managedRoot`, but it must
normalize to a strict descendant of that root. Evaluation checks paths
lexically; it does not inspect the receiving machine's filesystem.

`filesystemNamespace` identifies a filesystem, not an authority. Alice and a
system service writing on the same host must use the same namespace so their
claims can collide. Two active declarations claiming one normalized path are
an error even if their source content is identical. Source order never selects
a winner.

See the [declaration contract](declaration-contract.md) for authority scopes,
lifecycle strategies, retained artifacts, and executor capabilities.

## Generated content

A selected source can be a derivation:

```nix
source = {
  kind = "path";
  value = pkgs.writeText "application-colors.toml" ''
    background = "#202020"
  '';
};
onConflict = "source-wins";
```

Unselected source payloads stay lazy. Keep secrets out of these sources: Nix
store content and generated manifests are not secret storage.

## Compile without activation

The pure compiler can be used from another library or a test. This function
takes already-defined declarations, executors, and an Ownerships context:

```nix
{ lexicon, lib, resolve, resolveSystem, declarations, executors, ctx }:
let
  furnish = lexicon.lib.furnish { inherit lib resolve resolveSystem; };
in
furnish.compile {
  inherit declarations executors ctx;
  raw = { };
  provider = furnish.core.mkEnabledProvider { inherit resolve resolveSystem; };
}
```

The result contains `manifestData`, `manifestDocument`, `manifestJson`, and the
unchanged `raw` input. `manifestPath` is `null`; the runtime module materializes
it in the store.

If selection has already happened, use `furnish.core.offProvider`. It accepts
only untagged declarations, so a forgotten ownership key is an error rather
than an implicit global file. An empty declaration list does not force
resolvers or executor implementations.

## Lower home-relative entries

`files.mkDeclarations` converts file entries for selected user principals:

```nix
furnish.files.mkDeclarations {
  filesystemNamespace = "x86_64-linux/workstation";
  principals = [ {
    authority = { scope = "user"; identity = "alice"; };
    managedRoot = "/home/alice";
  } ];
  files = [ {
    src = ./config.fish;
    dest = ".config/fish/config.fish";
    representation = "writable";
    onConflict = "runtime-wins";
  } ];
}
```

It emits one declaration per entry and user principal. System principals are
skipped because a home-relative destination has no system home. Omitted
`representation` means `symlink`. Program uses this helper for application file
entries, but it is also available directly.

## Inspect and troubleshoot

Inspect the compiled system configuration:

```nix
config.lexicon.furnish.manifestData
config.lexicon.furnish.manifestPath
config.lexicon.furnish.ledgerPath
```

Don't hand-edit the generated manifest; the next build replaces it. Activation,
service ordering, and recovery are covered by [runtime integration](runtime-integration.md).

- A destination escape means the normalized path left its managed root or
  equaled the root itself.
- An executor error means no enabled executor supplies the lifecycle baseline
  and representation capabilities the declaration requires.
- An inactive declaration did not match its Ownerships context. Inspect its
  claims before changing its source.
- A claim reaching `offProvider` means selection is still needed upstream.
- An enabled runtime with no declarations emits an empty desired state so the
  coordinator can retire removed content.
