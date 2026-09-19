# Registry contents

Registry is the one place a configuration says which hosts and users exist. Every other subsystem asks that table instead of carrying its own fleet declaration. It records source roots, live roots, hosts, users, and membership, and compiles them into one normalized table and one Ownerships roster.

You do not have to use Registry when one standalone subsystem already has all the context it needs. It is useful when Ownerships, Program, Praxis, or another consumer would otherwise repeat the same fleet facts.

## Reading order

1. [Get started](getting-started.md) creates `lexicon.nix`, evaluates the normalized summary, and makes one visible change.
2. [Reference](reference.md) records every input field, output, default, validation rule, and boundary.
3. [Inherit a Den fleet](den.md) layers Den's existing roster under the same registry.

## The short version

```nix
registry = lexicon.lib.registry (import ./lexicon.nix);
```

`lexicon.nix` is the recommended file name, not a discovered or required name. `registry` receives an ordinary Nix value. The import may be inline, renamed, or moved without changing the contract.

[Back to the Lexicon manual](../README.md)
