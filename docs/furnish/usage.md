# Furnish tasks

Start with [getting started](getting-started.md) if you haven't evaluated a Furnish manifest yet. The sections here are independent; choose the task that matches the file you need to manage.

## Declare a store-backed symlink

Use `representation = "symlink"` for configuration that should always point at the retained Nix store artifact. The native runtime publishes a symlink whose target is the materialized `source.value`.

<!-- excerpt: ../../examples/furnish/files.nix -->
```nix
        managedRoot = "/home/river";
        destination = ".config/paperkite/settings.conf";
        # immutable settings stay tied to the retained store artifact
        representation = "symlink";
        source = {
          kind = "path";
          value = ./settings.conf;
        };
```

A relative `destination` is joined to `managedRoot`, so this compiles to `/home/river/.config/paperkite/settings.conf`. Omitting `onConflict` records the default policy, `error`, in the manifest.

Choose a symlink when the application can read immutable store content and runtime edits aren't part of the file's purpose. A changed symlink isn't silently replaced unless the ledger proves that it still matches Furnish's recorded ownership.

## Publish a writable copy

Use `representation = "writable"` when the application or user needs to change the destination after Furnish copies the source bytes into place. The native runtime creates a regular file with mode `0644`.

<!-- excerpt: ../../examples/furnish-policies/files.nix -->
```nix
        managedRoot = "/home/river";
        destination = ".local/share/paperkite/notes.txt";
        representation = "writable";
        onConflict = "runtime-wins";
        source = {
          kind = "path";
          value = ./sources/notes.txt;
        };
```

A runtime-only edit is preserved when the declared source hasn't changed. `onConflict` matters when the source and destination have both changed since the recorded baseline.

Use `source-wins` only for writable data whose generated source is authoritative:

<!-- excerpt: ../../examples/furnish-policies/files.nix -->
```nix
        destination = ".cache/paperkite/generated.conf";
        representation = "writable";
        onConflict = "source-wins";
        source = {
          kind = "path";
          value = ./sources/generated.conf;
        };
```

The complete focused example compiles these choices together:

```sh
nix eval --impure --json --file examples/furnish-eval.nix policies.manifest
```

<!-- furnish-value: policies.manifest -->
```json
[{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.cache/paperkite/generated.conf","destination":"/home/river/.cache/paperkite/generated.conf","namespace":"x86_64-linux/studio","onConflict":"source-wins","provenance":{"declaration":"paperkite generated index","source":"examples/furnish-policies/files.nix"},"representation":"writable"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.config/paperkite/settings.conf","destination":"/home/river/.config/paperkite/settings.conf","namespace":"x86_64-linux/studio","onConflict":"error","provenance":{"declaration":"paperkite settings","source":"examples/furnish-policies/files.nix"},"representation":"symlink"},{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.local/share/paperkite/notes.txt","destination":"/home/river/.local/share/paperkite/notes.txt","namespace":"x86_64-linux/studio","onConflict":"runtime-wins","provenance":{"declaration":"paperkite notes","source":"examples/furnish-policies/files.nix"},"representation":"writable"}]
```

## Choose a writable conflict policy

Furnish compares three hashes for an already-owned writable file: the recorded baseline, the current declared source, and the destination. Policy is consulted only when both source and destination moved away from the baseline and don't match each other.

| Policy | Two-sided divergence |
| --- | --- |
| `error` | Return a conflict diagnostic; leave destination and ledger unchanged |
| `source-wins` | Atomically publish source bytes and advance the baseline; changed runtime bytes may be discarded |
| `runtime-wins` | Leave destination bytes in place and advance the ledger to record that this source version was declined |

A source-only update publishes under every policy. A runtime-only edit is preserved under every policy. `runtime-wins` doesn't copy runtime bytes back into the Nix source.

For symlinks, `onConflict` is carried in the manifest but doesn't authorize replacement of an unowned or changed link. Symlink reconciliation uses exact recorded target evidence.

## Set authority deliberately

`authority.scope = "user"` runs staging and missing child-directory creation as the named account. `authority.identity` must resolve through the host's user database when reconciliation runs.

`authority.scope = "system"` runs those operations without user privilege reduction. Its identity must be a canonical string containing `/`, such as `x86_64-linux/studio`.

Use the user scope for paths managed on behalf of one account, normally beneath that account's home. Use system scope for paths such as `/etc/paperkite/service.conf` that are managed by the host configuration.

## Keep destinations inside their root

`managedRoot` is the boundary Furnish is allowed to walk. It must normalize to an absolute path other than `/`. The destination must normalize to a strict descendant of it.

These spellings reach the same canonical destination:

```nix
{
  managedRoot = "/home/river";
  destination = ".config/./paperkite/../paperkite/settings.conf";
}
```

The result is `/home/river/.config/paperkite/settings.conf`. A destination that uses `..` to escape the root fails during evaluation with `destination-validation: outside-managed-root`.

The managed root itself must exist at runtime. Furnish can create missing directories below it with mode `0755`; it doesn't create a missing root. Parent traversal refuses symlinks and non-directory components.

## Choose a filesystem namespace

`filesystemNamespace` joins the absolute destination to form the canonical ledger key:

```text
<namespace>:<absolute-destination>
```

Use a stable host identity, such as `x86_64-linux/studio`, and keep it stable across generations. Namespace changes make earlier records look undeclared and new entries look unowned. Different namespaces don't permit two declarations to target one physical path: both the compiler and coordinator reject duplicate destinations.

## Inspect without activation

Expose a projection from `config.lexicon.furnish.manifestData`, as the examples do, then use `nix eval`. Projecting selected fields keeps review output stable while the full entry retains its store target and executor metadata.

Useful checks before activation:

- every `filesystemIdentity.destination` is the expected absolute path;
- `authority` matches the account or system responsibility;
- writable files carry the intended `onConflict` choice;
- `provenance` names the declaration and source clearly;
- no unexpected declaration remains after a refactor.

`manifestPath` is non-null only when the runtime is enabled. Building it is safe and doesn't reconcile files:

```sh
nix build --no-link .#nixosConfigurations.demo.config.lexicon.furnish.manifestPath
```

The build may add the manifest and source artifacts to the Nix store. Activation and boot are the state-changing boundaries.

## Configure ledger state honestly

The defaults are:

```nix
{
  path = "/var/lib/furnish";
  durability = "ephemeral";
  requiresMountsFor = [ ];
}
```

`durability` is a host claim, not a persistence switch. If the root can be replaced, point `state.path` at storage that survives the replacement and include its backing mount in `state.requiresMountsFor`. The runtime doesn't create the mount or assert that it is durable.

The VM-backed runtime fixture uses `/persist/var/lib/furnish`, declares `durability = "durable"`, and adds `/persist` to the mount requirements. See [runtime and safety](runtime.md#make-state-durable-when-the-root-can-be-replaced) for the checked source excerpt and state-loss behavior.

## Understand enable and an empty set

With `enable = false`, `manifestData` remains available for inspection, while `manifestPath` is `null` and no activation script or boot service is installed.

With `enable = true`, an empty declaration list is an active desired state. Runtime reconciliation can retire entries recorded by older generations. Disable the runtime when you want it inert; don't use an enabled empty list as a no-op.

## Write useful labels and provenance

`label` appears in compile diagnostics and becomes `provenance.declaration` in the manifest. Make it describe the file's role, such as `paperkite generated index`.

Set `provenance.source` when the declaration came from a named module or generated collection:

```nix
{
  label = "paperkite settings";
  provenance.source = "modules/paperkite/files.nix";
}
```

If `provenance.source` is absent, Furnish uses the label. Other provenance values may pass current shape validation, but only `source` is projected into the current manifest entry.

## Generate user declarations from file entries

`files.mkDeclarations` is an integration helper for callers that already have Furnish's library value and a principal list. It emits one declaration per file for each user principal, defaults the root to `/home/<identity>`, and skips system principals. See [advanced reference](advanced-reference.md#file-declaration-helper) for its exact call and output.

## Diagnose common declaration failures

- **Malformed declaration:** check every required field and both nested records against the [reference](reference.md#declaration-fields).
- **Destination escape:** remove `..` segments that leave the root, or choose the correct root.
- **Duplicate destination:** search the compiled manifest projection for the absolute path; namespace changes don't make one physical destination safe twice.
- **No capable executor:** use `symlink` or `writable` with `furnishRuntime`, or supply a qualified custom executor through the compiler integration.
- **Pre-existing destination at runtime:** move or deliberately resolve the foreign file outside Furnish; equality isn't adoption proof.
- **Ownership claim rejected:** direct `lexicon.furnish.declarations` use the off provider. Enabled-provider claims belong to compiler integrations described in [advanced reference](advanced-reference.md#providers-and-ownerships-claims).

Labels and `provenance.source` are included with runtime diagnostics, so they should identify the declaration without requiring a source-code search.

[Back to Furnish](README.md) · [Runtime and safety](runtime.md) · [Reference](reference.md)
