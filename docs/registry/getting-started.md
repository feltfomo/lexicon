# Register the fleet first

Registry gives the rest of Lexicon one table of hosts, users, membership, and roots. This lesson evaluates a complete registry, changes it, and then uses the same files as an ordinary flake. Nothing is installed or activated.

If you have not prepared Nix and a Lexicon checkout, follow [preparation](../preparation.md). Run the checkout commands below from the repository root.

## Write `lexicon.nix`

Open `examples/registry-minimal/lexicon.nix`. It is the complete declaration used by this lesson:

<!-- source: ../../examples/registry-minimal/lexicon.nix -->
```nix
{
  root = ./.;
  runtimeRoot = "/etc/paperkite";
  defaultSystem = "x86_64-linux";

  dimensions.role = {
    values = [
      "desktop"
      "server"
    ];
    required = true;
  };

  hosts.workstation = {
    aliases = [
      "workstation"
      "desk"
    ];
    dimensions.role = "desktop";
    users.river = {
      aliases = [
        "river"
        "operator"
      ];
    };
  };

  users = { };
}
```

`root` is the source tree Nix can copy into the store. `runtimeRoot` is an optional absolute path to a live checkout. They stay separate because a store source and a directory used by a running command are not interchangeable. `root`, `runtimeRoot`, `hosts`, and `users` must all be written, even when the answer is `null` or `{ }`, so an empty fleet is a decision rather than an omission.

Hosts are keyed by bare name. `defaultSystem` supplies the system for hosts that do not name one, and the pair becomes the canonical host id `<system>/<host>`.

`dimensions` declares a closed space of host classifications. Declaring `role` with `values` and `required` means a typo in a value, or a host that omits the value, fails at evaluation. Declaring no dimensions at all leaves classifications unchecked.

Users written under a host register membership there. A user that spans hosts can instead be written once under the top-level `users` table.

## Compile it

The complete example flake imports that value explicitly:

<!-- source: ../../examples/registry-minimal/flake.nix -->
```nix
{
  description = "One shared Lexicon registry";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { lexicon, ... }:
    let
      registry = lexicon.lib.registry (import ./lexicon.nix);
    in
    {
      lib = {
        inherit registry;
        inherit (registry) summary;
        desk = registry.host "desk";
        home = registry.homeFor {
          host = "workstation";
          user = "operator";
        };
      };
    };
}
```

`lexicon.lib.registry` receives the imported Nix value. Lexicon does not search for `lexicon.nix`; the name is a convention that keeps the shared declaration easy to find.

The full table is available as `lib.registry`. The smaller `lib.summary` output keeps this lesson's result JSON-readable. `registry.host "desk"` resolves an alias, and `registry.homeFor` answers where one user lives on one host.

## Evaluate the summary

From the Lexicon repository root, run:

```sh
nix eval --impure --json --file examples/registry-eval.nix minimal.result
```

It prints:

```json
{
  "hosts": ["workstation"],
  "systems": ["x86_64-linux"],
  "users": ["river"]
}
```

The host id in the underlying roster is `x86_64-linux/workstation`. The user declaration under that host becomes membership for `river`; no account is created.

## Make a visible change

The supplied changed projection adds a second host to the same declaration:

```nix
hosts.vault.dimensions.role = "server";
```

Evaluate it:

```sh
nix eval --impure --json --file examples/registry-eval.nix minimal.changed
```

The result is identical except for:

```json
"hosts": ["vault", "workstation"]
```

`vault` takes its system from `defaultSystem`, and `role = "server"` is accepted because `server` is one of the declared dimension values. Writing an undeclared value instead fails with a Registry diagnostic and a suggested spelling.

## Use it as an ordinary flake

Copy `examples/registry-minimal/flake.nix` and `lexicon.nix` into an empty project directory. From that directory, run:

```sh
nix flake lock
nix eval --json .#lib.summary
```

The first command records the selected Lexicon revision in `flake.lock`. The second evaluates the same summary through the consumer flake.

In an existing flake, add the Lexicon input beside the current inputs, accept `lexicon` in the current output function, and bind the registry in its existing `let`. Do not replace unrelated inputs or outputs.

Once bound, the shared facts are ordinary Nix values:

```nix
program = lexicon.lib.programOwnerships {
  roster = registry.roster;
};

context = registry.context {
  host = "workstation";
};

servers = registry.hostsWhere { role = "server"; };
```

Use the [reference](reference.md) for every field and result. If the fleet already lives in Den, continue with [inherit a Den fleet](den.md) instead of repeating `hosts`.

[Registry contents](README.md) · [Examples](../../examples/README.md#registry)
