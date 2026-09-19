# Optional Ownerships selection

Praxis works without Ownerships. Add this path only when the available commands genuinely depend on an explicit host or user context.

## Select declarations for one context

<!-- source: ../../examples/praxis-ownerships/flake.nix -->
```nix
{
  description = "Optional Ownerships selection for Praxis";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ownerships = lexicon.lib.ownerships { inherit (nixpkgs) lib; };
      roster = ownerships.toRoster [
        (ownerships.define.host "desk" { system = "x86_64-linux"; })
        (ownerships.define.host "away" { system = "aarch64-linux"; })
        (ownerships.define.user "river" { hosts = [ "desk" ]; })
      ];
      # explicit selection exposes only commands available in this context
      published = lexicon.lib.praxis {
        inherit pkgs;
        ownership = {
          inherit roster;
          scope = "user";
          context = {
            host.id = "x86_64-linux/desk";
            user.name = "river";
          };
        };
        commands = {
          common = [ "${pkgs.coreutils}/bin/true" ];
          local = {
            hosts = [ "desk" ];
            users = [ "river" ];
            command = [ "${pkgs.coreutils}/bin/true" ];
          };
          away = {
            hosts = [ "away" ];
            command = [ "${pkgs.coreutils}/bin/false" ];
          };
        };
        units = [
          {
            hosts = [ "desk" ];
            children = [
              {
                users = [ "river" ];
                commands.review = [ "${pkgs.coreutils}/bin/true" ];
              }
            ];
          }
        ];
      };
      adapters = lexicon.lib.praxisAdapters { inherit (nixpkgs) lib; };
    in
    published.flake
    // {
      lib = {
        inherit (published) availability;
        choices = adapters.fromRoster roster;
        denChoices = adapters.fromDen { inherit roster; };
      };
    };
}
```

The public Ownerships roster and explicit user context make `common`, `local`, and nested `review` invocable. The `away` command is not available in that context.

<!-- praxis-command: ownerships.summary -->
```sh
nix eval --impure --json --file examples/praxis-eval.nix ownerships
```

<!-- praxis-value: ownerships -->
```json
{"denMatches":true,"hostChoices":["aarch64-linux/away","x86_64-linux/desk"],"names":["common","local","review"],"userChoices":["river"]}
```

Command and task declarations accept Ownerships claim fields when `ownership` is configured. Nested `units` can place claims around groups of commands and tasks; units without an ownership configuration are rejected. `availability.names` reports selected names, while `availability.trace` and `availability.matrix` expose Ownerships inspection results. Use the [Ownerships manual](../ownerships/README.md) for full claim, roster, and context semantics.

## Keep adapters narrow

`lexicon.lib.praxisAdapters { inherit (nixpkgs) lib; }` returns `fromRoster` and `fromDen`.

- `fromRoster roster` returns sorted `host` and `user` parameter records with `name` and `choices`.
- `fromDen adapter` reads `adapter.roster` and returns the same records.

The helpers do not insert those records into a command. `fromDen` does not bind runtime execution to Den, instantiate hosts, or create a full Den integration. The example exposes both results for comparison.

Continue with the standalone [worked reporting project](worked-example.md).
