# Inherit a Den fleet

Pass `den` in the declaration when Den already declares the hosts, users, and dimensions in a configuration. It avoids a second fleet declaration while keeping one registry as the answer to which hosts and users exist.

A declaration without `den` is the ordinary path for configurations that do not use Den.

## Bind the existing fleet

`den` is an ordinary declaration field, so the same `lexicon.nix` shape is used:

```nix
{ den }:
{
  inherit den;

  root = ./.;
  runtimeRoot = "/etc/my-config";

  hosts = { };
  users = { };
}
```

At the composition root where `den` is already available, bind it once:

```nix
registry = inputs.lexicon.lib.registry (import ./lexicon.nix { inherit den; });
```

The result has the same `hosts`, `users`, `roster`, `context`, and lookup fields as a registry without Den.

## What is inherited

The Den layer reads the roster projected by Lexicon's existing Den adapter. That roster supplies:

- every host in `den.hosts`;
- canonical `<system>/<host>` ids;
- host dimensions;
- host aliases and display names;
- user ids, aliases, display names, and host membership.

Host-local user homes default to `/home/<name>` because the roster deliberately does not force Den user values. A consumer that needs a different home may set it in the `lexicon.nix` layer.

Registry keys hosts by bare name, so a Den fleet that reuses one host name on more than one system fails with `den-host-name-conflict`. Rename one of them in Den before registering it.

## Two layers, one table

Unlike a single-authority model, Den and `lexicon.nix` are layers of the same registry. They merge per field, and the `lexicon.nix` layer wins:

- writing `hosts.<name>` for a Den host refines that host instead of replacing the fleet;
- writing `hosts.<name> = null;` removes a Den host outright, and withdraws the membership that host implied;
- writing a host Den does not know adds it;
- every record's `origin` says which layers produced it.

Excluding a name no layer declares fails with `exclude-no-match`, so a stale exclusion is reported rather than ignored.

## What stays lazy

Building the registry does not instantiate hosts or evaluate user bodies and aspects. `den` is held unvalidated and unforced by the declaration schema; the Den layer reads host records only far enough to enumerate user attribute names and dimensions, which is the same boundary used by `lexicon.lib.den` today. Reading `registry.root` never builds the user table.

## Consume the inherited registry

Program can use the common roster without a Den-specific application declaration:

```nix
program = inputs.lexicon.lib.programOwnerships {
  roster = registry.roster;
};
```

Praxis can use the same selected context:

```nix
ownership = {
  inherit (registry) roster;
  scope = "system";
  context = registry.context { host = "workstation"; };
};
```

Keep `lexicon.lib.den { inherit den; }` when another feature needs the Den adapter's installer functions. Registry does not absorb those lifecycle operations.

[Registry contents](README.md) · [Reference](reference.md)
