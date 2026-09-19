# Advanced and custom Program binding

Use this page only when an integration framework must provide its own resolution and principal model. Ordinary fixed-target configurations should use [`programDirect`](getting-started.md); roster-based configurations should prefer [`programOwnerships`](ownerships.md) or [`programDen`](den.md).

## Callback constructor

The original constructor remains public and compatible:

```nix
program = lexicon.lib.program {
  resolve = ...;
  resolveSystem = ...;
  resolvePrepared = ...;
  filePrincipals = ...;
  hostUserNames = ...;
};
```

It returns the same `program { ... }` declaration function as the other constructors. Claims are accepted because their interpretation belongs to the supplied resolvers.

## Resolver callbacks

`resolve` and `resolveSystem` use the Ownerships-compatible shape:

```nix
resolve units context
resolveSystem units systemContext
```

Program's Furnish compiler uses those callbacks at its existing integration boundary. `resolve` handles host-and-user values; `resolveSystem` handles host-only values.

`resolvePrepared` is called in two stages:

```nix
prepared = resolvePrepared units;
resolved = prepared context;
```

Program builds the prepared Home Manager and file unit sets once per declaration closure, then calls each prepared resolver for the active context. A custom implementation must preserve the same selected values, claim semantics, nested ownership, merge behavior, and inactive-payload laziness expected by its public declaration model.

A framework using Ownerships directly can obtain compatible callbacks from `ownerships.mkResolvers roster`:

```nix
resolvers = ownerships.mkResolvers roster;
program = lexicon.lib.program {
  inherit (resolvers) resolve resolveSystem;
  resolvePrepared = resolvers.prepared;
  filePrincipals = ...;
  hostUserNames = ...;
};
```

Prefer `programOwnerships { inherit roster; }` unless the framework has a genuine reason to own the remaining callbacks.

## File principals

Program calls:

```nix
filePrincipals {
  system = "x86_64-linux";
  host = "studio";
  user = selectedUserOrNull;
}
```

The callback returns a list of principal records. Program file helpers consume user principals and ignore system principals. A user principal has this shape:

```nix
{
  authority = {
    scope = "user";
    identity = "river";
  };
  managedRoot = "/home/river";
  ctx = {
    host = { ... };
    user = { ... };
  };
}
```

`managedRoot` and `ctx` are optional at this callback boundary when the surrounding integration supplies equivalent defaults or does not need context on the principal. For predictable nonstandard homes, return `managedRoot` explicitly. For one user-selected Program slice, return only that user's principal; returning every host user duplicates file declarations.

## Host user names

Program calls:

```nix
hostUserNames {
  system = "x86_64-linux";
  host = "studio";
}
```

Return the user names known on that host. Program uses the list only to make the no-principal diagnostic actionable when selected files reach no user authority.

## NixOS context

With the callback constructor, the module arguments supplied to `homeManager` and `nixos` are the dynamic selection context. Host values should carry a canonical `id` when file namespaces must survive host aliases or renames. User values should identify the selected user and may carry a nonstandard `home` for a framework's own resolution model.

The direct constructor is intentionally different: it captures its target once and ignores module-provided `host` and `user` arguments for selection. Do not emulate direct mode by supplying mutable module context to custom callbacks.

## Den adapter boundary

`programDen` obtains its roster, file principals, and host-user names through Lexicon's public Den adapter boundary, then delegates to the Ownerships binding. Integrations should not copy Den-internal traversal into application files. The helper does not require or invoke unrelated host-instantiation machinery during ordinary Program evaluation.

## Compatibility and validation responsibilities

A custom binding must preserve:

- Program's selected declaration values and merge semantics;
- canonical host identity for file namespaces;
- exactly the selected user principal for user-file publication;
- empty results for inactive slices without forcing their payloads;
- separate system-only and host-user resolution doors;
- a reusable prepared resolver rather than rebuilding static translation for every user;
- actionable user inventory for no-principal failures.

The repository's Program boundary suite retains callback-constructor coverage alongside direct, Ownerships, and Den binding assertions. The safe file regression build exercises the callback path used by the existing NixOS fixture without activating it.

Internal `binding` records accepted by the implementation are not a public fifth constructor. Use one of the four flake exports documented in the [reference](reference.md#public-constructors).

[Program contents](README.md) · [Reference](reference.md) · [Den integration](den.md)
