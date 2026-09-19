# Runtime and safety

Furnish has a safe inspection path and a state-changing reconciliation path. Keep them separate when reviewing a configuration.

| Action | Builds or evaluates desired state | Can change declared destinations |
| --- | --- | --- |
| Evaluate `manifestData` or a projected flake output | Yes | No |
| Build `manifestPath` with `--no-link` | Yes | No |
| Build a NixOS system closure | Yes | No |
| Activate a configuration with Furnish enabled | Yes | Yes |
| Boot a configuration with Furnish enabled | Uses the built manifest | Yes |

Evaluation can copy source artifacts into the Nix store. It doesn't reconcile `/home`, `/etc`, or any other declared root.

## Enabled and disabled configurations

With `lexicon.furnish.enable = false`, declarations still compile into the read-only `manifestData` output. `manifestPath` is `null`, and the module doesn't add the coordinator package, activation script, or `furnish.service`.

<!-- furnish-value: runtime.disabled -->
```json
{"enabled":false,"manifest":[{"authority":{"identity":"river","scope":"user"},"canonical":"x86_64-linux/studio:/home/river/.config/paperkite/settings.conf","destination":"/home/river/.config/paperkite/settings.conf","namespace":"x86_64-linux/studio","onConflict":"error","provenance":{"declaration":"disabled inspection","source":"tests/furnish-examples.nix"},"representation":"symlink"}],"manifestAvailable":false,"serviceEnabled":false}
```

With `enable = true`, the module materializes `manifestPath`, retains declaration sources in the system closure, adds `furnish-coordinator`, and installs both reconciliation entry points.

- The activation script runs after users are created. During boot-stage activation it defers to the service.
- The oneshot `furnish.service` runs after local filesystems and is wanted by `multi-user.target`.
- The service receives mount dependencies for every compiled destination plus `state.requiresMountsFor`.

## An enabled empty manifest is active desired state

Enabling the runtime with no declarations still writes an empty manifest and installs both reconciliation entry points:

<!-- furnish-value: runtime.empty -->
```json
{"activationEnabled":true,"entryCount":0,"manifestAvailable":true,"serviceEnabled":true}
```

At runtime, an empty manifest requests retirement of every destination that remains provably Furnish-owned in the ledger. That makes `enable = true; declarations = [ ];` different from disabling the module. It can remove an unchanged managed symlink or an unchanged writable file left by an older generation.

Retirement is conservative:

- a symlink is removed only when it still points to the target recorded as Furnish-owned;
- a writable file is removed only when its bytes still match the recorded baseline;
- an edited writable file is preserved and recorded as an unresolved retirement;
- a changed representation or unprovable object is refused.

The retirement sweep runs only after every desired entry succeeds. If a desired entry fails, undeclared records aren't retired in that run.

## Manifest and ledger

`manifestPath` is the built desired-state document for the current configuration. It contains what Furnish should manage, including retained source targets and executor choices.

`ledgerPath` is `${state.path}/applied-state.json`. The ledger records what the running machine actually applied. It supplies the ownership and writable-baseline evidence needed for updates, repairs, and retirement; it isn't regenerated from the current manifest.

An absent ledger is a cold start with no ownership evidence. Furnish can acquire an absent destination, but it refuses to adopt an existing symlink or regular file even when it already matches the source. Equality alone isn't proof that Furnish created the object.

Don't delete the ledger to clear an error. After state loss, existing destinations are unowned: Furnish can't safely update, repair, or retire them from declaration equality alone.

## Make state durable when the root can be replaced

`state.durability` is a declared host fact. The runtime doesn't create persistence or verify the backing filesystem. If a host replaces its root at boot, place `state.path` on storage that survives that replacement and order reconciliation after the backing mount.

The system fixture uses:

<!-- excerpt: ../../tests/system/fixture/host.nix -->
```nix
  lexicon.furnish = {
    enable = true;
    state = {
      path = "/persist/var/lib/furnish";
      durability = "durable";
      requiresMountsFor = [ "/persist" ];
    };
  };
```

This block doesn't create `/persist`; the fixture's disk and mount configuration does. On a real host, prove the same persistence property in that host's filesystem configuration. If the host also needs that filesystem during early boot, express that separately in its filesystem configuration; Furnish only adds the paths named in `requiresMountsFor` to its own ordering.

## Writable divergence

For an owned writable file, let **B** be the last recorded baseline, **S** the current source, and **D** the destination.

| Relationship | Result |
| --- | --- |
| `D = S = B` | Steady state; keep the applied generation |
| `S = B`, `D ≠ B` | Preserve the runtime edit |
| `D = B`, `S ≠ B` | Publish the source update |
| `D = S`, `B ≠ S` | Verify and advance a stale baseline as recovery |
| All three differ | Consult `onConflict` |

For genuine two-sided divergence:

- `error` emits a conflict and changes neither destination nor ledger;
- `source-wins` publishes the source and may discard displaced runtime bytes;
- `runtime-wins` preserves the destination and records that the current source version was declined, without incrementing the apply generation.

A writable record without a baseline is refused under every policy. A representation change from writable to symlink is also refused when the writable destination has edited bytes.

## Symlink ownership and repair

A matching symlink with no ledger record is left untouched and remains unowned. With a record, Furnish can update the link only when the observed target still equals the recorded target. A missing owned link is repaired; a changed link is refused.

When the recorded store target has been collected, Furnish classifies a valid replacement as repair. It verifies that the new desired target resolves before publishing it, so a repair doesn't manufacture a broken link.

## What to review before activation

Before enabling runtime reconciliation on an existing host:

1. Inspect `manifestData` and confirm every absolute destination, representation, authority, and policy.
2. Confirm each managed root already exists and each user authority resolves on the host.
3. Check for pre-existing destinations. Furnish won't adopt them automatically.
4. Confirm `state.path` persists for the host's storage model and add backing mounts to `state.requiresMountsFor`.
5. Remember that an enabled empty declaration set can retire previously managed entries.

Evaluation and builds do not activate these configurations, exercise destructive recovery, or establish that a particular host's filesystem state is conflict-free.

[Back to Furnish](README.md) · [Usage](usage.md) · [Reference](reference.md)
