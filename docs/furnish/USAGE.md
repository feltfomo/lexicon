# Using Furnish

Furnish decides what files should exist on a machine and keeps them that way.
The Nix side is a pure compiler that produces a manifest. A Rust coordinator
reads that manifest during activation and boot and does the actual work.

Most people should use `program.files` and `program.directories`. This guide is
for the cases where you want the file machinery without the aspect layer.

## Why not just symlink into the store

A store symlink is immutable. That is exactly right for a config file you own
and exactly wrong for a config file the application owns.

Plenty of programs rewrite their own config — they persist window positions, a
last-opened path, a theme toggle you flipped in a GUI. Symlink it and the write
fails or the app replaces your link. Copy it by hand and you have no idea, six
months later, whether the file on disk still matches what you declared.

That is the `writable` representation.

| Representation | On disk | Good for |
| --- | --- | --- |
| `symlink` | a link into the Nix store | files you own outright |
| `writable` | real content, copied | files the application also writes |

A `writable` file is tracked against an applied-state ledger, so Furnish can
tell the difference between a file you changed, a file the app changed, and a
file that drifted. What it does about that is your `onConflict` choice.

| Policy | Meaning |
| --- | --- |
| `error` | divergence from the recorded baseline stops the rebuild |
| `source-wins` | your declared content is restored |
| `runtime-wins` | whatever is on disk is kept |

`runtime-wins` is the honest answer for a file an app genuinely owns. Use
`error` when you want to know before anything is overwritten.

## Standalone compile

Furnish needs Ownerships resolvers, because selection is an ownership question:

```nix
let
  ownerships = import ./src/ownerships { inherit lib krisis axiom; };

  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { system = "x86_64-linux"; })
    (ownerships.define.user "feltfomo" { hosts = [ "khion" ]; })
  ];

  furnish = import ./src/furnish {
    inherit lib krisis axiom;
    resolve = ownerships.mkResolve roster;
    resolveSystem = ownerships.mkResolveSystem roster;
  };
in
furnish.compile {
  declarations = [ ... ];
  executors = [ ... ];
  ctx = {
    host = { name = "khion"; system = "x86_64-linux"; };
    user = { name = "feltfomo"; };
  };
  raw = { };
  provider = furnish.core.mkEnabledProvider {
    resolve = ownerships.mkResolve roster;
    resolveSystem = ownerships.mkResolveSystem roster;
  };
}
```

You get back `manifestData`, `manifestDocument`, `manifestJson`, and your `raw`
passed through untouched. `manifestPath` is `null` — writing to the store is
`runtime.nix`'s job, not the compiler's.

An empty declaration list is a genuine no-op. It will not force your resolvers
or your executors.

### If selection already happened

When the caller has already picked the declarations for this principal, use
`furnish.core.offProvider` instead. It accepts only untagged declarations, and
a leftover ownership key is a loud error rather than a silent promotion to
global.

## A writable declaration

```nix
{
  label = "ghostty config";
  filesystemNamespace = "x86_64-linux/khion";
  authority = {
    scope = "user";
    identity = "feltfomo";
  };
  managedRoot = "/home/feltfomo";
  destination = ".config/ghostty/config";
  representation = "writable";
  source = {
    kind = "path";
    value = ./ghostty-config;
  };
  onConflict = "runtime-wins";
  provenance.source = "configuration/terminals.nix";
}
```

The destination may be absolute or relative to `managedRoot`. It is normalized
lexically and must end up a strict descendant of the root. No filesystem lookup
happens during evaluation, so this proof holds during a pure build.

See [the declaration contract](declaration-contract.md) for every field.

## Generated content

`source.value` is lazy and is only forced if the declaration is selected, so it
can be a derivation:

```nix
{
  label = "generated theme";
  representation = "writable";
  source = {
    kind = "path";
    value = pkgs.writeText "colors.toml" (builtins.toJSON palette);
  };
  onConflict = "source-wins";
  # ...
}
```

`source-wins` fits generated content. The file is derived from your
configuration, so a local edit is drift and restoring it is correct.

## Lowering home-relative files

If you already have a list of `{ src, dest }` entries, `files.mkDeclarations`
does the lowering:

```nix
furnish.files.mkDeclarations {
  filesystemNamespace = "x86_64-linux/khion";
  principals = [
    {
      authority = {
        scope = "user";
        identity = "feltfomo";
      };
      managedRoot = "/home/feltfomo";
    }
  ];
  files = [
    {
      src = ./fish/config.fish;
      dest = ".config/fish/config.fish";
      representation = "writable";
      onConflict = "runtime-wins";
    }
  ];
}
```

One declaration per entry per user principal. System principals are skipped,
because a home-relative destination has no meaning for one. An absent
`representation` stays `symlink`, which keeps existing call sites behaving the
way they already did.

## Wiring the runtime

The NixOS module is curried on its cross-repo dependencies, because a module
cannot be handed flake inputs:

```nix
furnishRuntime = inputs.lexicon.lib.furnishRuntime { inherit krisis axiom; };
```

Apply it once and pass the result around. Then:

```nix
{
  imports = [ furnishRuntime ];

  lexicon.furnish = {
    enable = true;
    state = {
      path = "/var/lib/furnish";
      durability = "durable";
      requiresMountsFor = [ "/var/lib" ];
    };
    declarations = [ ... ];
  };
}
```

`durability` is an assertion about your storage layout, not a request. Furnish
does not arrange persistence itself. If `/var/lib` is on tmpfs, say `ephemeral`
and mean it — the coordinator's safety reasoning depends on knowing whether the
ledger survives a reboot.

See [runtime integration](runtime-integration.md) for activation ordering, the
service, and the ledger contract.

## Collisions

Two declarations claiming one path is an error, even when both would write
identical content. Source order never picks a winner, and the diagnostic lists
every claimant with its authority and provenance.

The check is host-wide, not per-user. `buildHostIndex` projects every
declaration across every principal before comparing, which is what catches one
user colliding with another, or a user colliding with system authority.

Identity is `<filesystem namespace>:<absolute destination>`:

```text
x86_64-linux/khion:/home/feltfomo/.config/ghostty/config
```

The namespace is the filesystem, not the authority. Several authorities write
into one host's filesystem, which is exactly why the index is keyed this way.

## Inspecting what was compiled

```nix
config.lexicon.furnish.manifestData
config.lexicon.furnish.manifestPath
config.lexicon.furnish.ledgerPath
```

Do not hand-edit the generated manifest. It is a system-closure artifact and
the next evaluation replaces it.

## Troubleshooting

**Destination escapes the managed root.** Normalization is lexical and `..` is
not allowed to climb out. The destination also cannot equal the root itself.

**No executor satisfies a declaration.** An executor needs
`lifecycle-baseline` plus the capability matching your `representation`. The
error lists the enabled executors and what each one can do.

**A declaration was silently skipped.** It was inactive, not dropped. Its
ownership claim did not match the context you compiled for.

**An ownership key reached `offProvider`.** Selection was supposed to happen
upstream. Treating a leftover claim as global would install a file on a machine
that never asked for it, so it is an error instead.

**An enabled host has no declarations.** It still gets a manifest, with an
empty entry list. That is deliberate — an empty desired state is how the
coordinator learns to retire files that left your configuration.
