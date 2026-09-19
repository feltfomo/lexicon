# Add optional Ownerships selection

Use `programOwnerships` when application declarations must select hosts or users. It accepts the public roster from Ownerships and constructs Program's resolver and principal wiring internally.

This is an optional binding mode. A fixed target should continue to use [`programDirect`](getting-started.md).

## Define the roster

The focused example declares one host and two users with the public Ownerships surface:

<!-- source: ../../examples/program-ownerships/roster.nix -->
```nix
{ ownerships, system }:
ownerships.toRoster [
  (ownerships.define.host "studio" { inherit system; })
  (ownerships.define.user "alice" { hosts = [ "studio" ]; })
  (ownerships.define.user "bob" { hosts = [ "studio" ]; })
]
```

Use the [Ownerships getting-started path](../ownerships/getting-started.md) to build a roster from scratch. Its [reference](../ownerships/reference.md) is the authority for aliases, canonical host IDs, claims, predicates, nested selection, and merge behavior.

## Bind Program once

`program-binding.nix` is the whole Program-specific binding:

<!-- source: ../../examples/program-ownerships/program-binding.nix -->
```nix
{ lexicon, roster }:
# this constructor adds selection only where the application needs claims
lexicon.lib.programOwnerships { inherit roster; }
```

The returned value is the same small `program` function used by direct application files. No application file receives `resolve`, `resolveSystem`, `resolvePrepared`, `filePrincipals`, or `hostUserNames`.

## Add a claim to an application

The example selects Alice at declaration scope:

<!-- source: ../../examples/program-ownerships/editor.nix -->
```nix
{ program }:
program {
  users = [ "alice" ];
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  files = [
    {
      dest = ".config/helix/config.toml";
      src = ./config.toml;
    }
  ];
}
```

The module graph supplies a canonical `host` context and one `user` context per evaluated user slice. Unlike direct mode, those module arguments are the selection context.

Evaluate the checked comparison from the Lexicon root:

```sh
nix eval --impure --json --file examples/program-eval.nix ownerships.result
```

<!-- program-value: ownerships.result -->
```json
{
  "alice": {
    "editor": "hx",
    "files": ["/home/alice/.config/helix/config.toml"]
  },
  "bob": {
    "editor": null,
    "files": []
  },
  "outputs": ["homeManager", "nixos"]
}
```

The declaration's static output shape contains both modules because it has Home Manager imports and files. Resolution determines their content: Alice receives the import and one user-authority file declaration; Bob receives neither. Program publishes a selected user file to exactly that user's principal rather than enumerating every user on the host.

## Where claims may appear

Ownerships-backed Program accepts `hosts`, `users`, `exceptHosts`, `exceptUsers`, and `when` at these Program boundaries:

- the declaration;
- each file;
- each directory;
- each directory file rule;
- a theme or template according to the selected theme syntax;
- each renderer override.

Parent claims own their nested entries, and child claims may narrow them. Global entries without claims remain global. Inactive file, directory, and theme payloads stay lazy; malformed values behind an inactive claim are not forced for another context. NixOS slices use canonical host selection, while Home Manager and file publication use host-and-user selection.

Use the [Ownerships usage guide](../ownerships/usage.md) for the complete selection model rather than duplicating it here. Program adds application field validation and output lowering after Ownerships selects the active values.

## Choosing this mode

Choose `programOwnerships` when one shared application declaration needs selection. Do not add a roster merely because a repository has more than one host: separate direct bindings are often simpler when application files do not share claims.

The exact constructor, roster validation, and claim availability table are in the [Program reference](reference.md#binding-modes-and-claims).

[Program contents](README.md) · [Direct usage](usage.md) · [Den integration](den.md)
