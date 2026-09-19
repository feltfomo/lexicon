# Using Ownerships

These examples build on [getting started](getting-started.md). Run every command from the Lexicon root with the [prepared evaluator](../preparation.md#check-nix). Each command loads the named example from this checkout.

## Choose settings for more people and machines

The [preferences example](../../examples/ownerships/) contains [flake.nix](../../examples/ownerships/flake.nix) and [preferences.nix](../../examples/ownerships/preferences.nix). Its roster adds a workstation and Sam. Alice uses both machines; Sam uses the workstation.

The units supply Git to everyone, Helix to Alice, and a low-power setting on the laptop. Evaluate all three cases:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix preferences.alice
nix eval --impure --json --file examples/ownerships-eval.nix preferences.sam
nix eval --impure --json --file examples/ownerships-eval.nix preferences.laptop
```

Alice on the workstation:

<!-- value: preferences.alice -->
```json
{"tools":["git","helix"]}
```

Sam on the workstation:

<!-- value: preferences.sam -->
```json
{"tools":["git"]}
```

Alice on the laptop:

<!-- value: preferences.laptop -->
```json
{"lowPower":true,"tools":["git","helix"]}
```

A unit without claims applies globally. Matching units contribute together: the two tool lists concatenate in declaration order. These tools are strings in a result, not installed packages.

This example uses `x86_64-linux/workstation` and `x86_64-linux/laptop` as host IDs. The roster gives their bare names as aliases for claims; the context passes `host.id` explicitly. See [host identity](reference.md#host-identity-and-membership) when you add systems or aliases.

## Narrow a group of settings

The [claims example](../../examples/ownerships-claims/) has two complete files: [flake.nix](../../examples/ownerships-claims/flake.nix) supplies the roster and contexts, while [units.nix](../../examples/ownerships-claims/units.nix) holds the settings.

The first list item in `examples/ownerships-claims/units.nix` is the parent and its nested declarations. This is an excerpt; follow the file link above for the complete runnable input.

<!-- excerpt: ../../examples/ownerships-claims/units.nix -->
```nix
  {
    hosts = [
      "workstation"
      "laptop"
    ];
    tools = [ "git" ];
    # children can only narrow the parent match
    children = [
      {
        users = [ "alice" ];
        tools = [ "helix" ];
        children = [
          {
            exceptHosts = [ "workstation" ];
            editor.wrap = true;
          }
        ];
      }
      {
        exceptUsers = [ "alice" ];
        tools = [ "vim" ];
      }
    ];
  }
```

The parent applies to both hosts and contributes Git. Its children add Helix for Alice or Vim for users other than Alice. Alice's nested child excludes the workstation, leaving the wrapping preference on the laptop. Nesting narrows the parent's claim; it doesn't replace it.

```sh
nix eval --impure --json --file examples/ownerships-eval.nix claims.alice
nix eval --impure --json --file examples/ownerships-eval.nix claims.sam
nix eval --impure --json --file examples/ownerships-eval.nix claims.laptop
```

The workstation results are `{"tools":["git","helix"]}` for Alice and `{"tools":["git","vim"]}` for Sam. Alice's laptop result is:

<!-- value: claims.laptop -->
```json
{"editor":{"wrap":true},"lowPower":true,"tools":["git","helix"]}
```

`exceptHosts` and `exceptUsers` select a roster's complement. A unit can use an include or an exclusion for an axis, but not both on that same unit. A child can add an exclusion beneath a parent's include, as this example does. A disjoint nested claim is an error even when you're evaluating a different host; use a sibling unit if you mean a different group.

## Select by a property of the context

The claims example also supplies `host.mobile` in its context and uses this snippet from `units.nix`:

```nix
{
  # the predicate stays defined when mobile is absent from the context
  when = { host, ... }: host.mobile or false;
  lowPower = true;
}
```

`when` receives the context and must return a Boolean. `host.mobile or false` reads that field with a fallback when it is absent. A predicate is useful for properties such as a mobile machine, rather than repeating a list of names.

Pass those properties inside `host` or `user`. The default factory passes those two entities to predicates, not arbitrary top-level fields, and it doesn't fill them from roster metadata. Nested predicates must all hold. Keep them well-defined for every modeled context, including contexts you later use for inspection.

## Merge shared data deliberately

Open the [merge example's flake](../../examples/ownerships-merge/flake.nix) and [values.nix](../../examples/ownerships-merge/values.nix). It combines shared editor settings with Alice's additions:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix merge.combined
```

<!-- value: merge.combined -->
```json
{"editor":{"command":"helix","tabWidth":2,"wrap":true},"tools":["git","git","ripgrep"]}
```

Ordinary attribute sets merge recursively. Lists concatenate, including duplicates. Equal terminal values agree; different ones cause an error rather than silently taking the last declaration. The [merge defaults](reference.md#merge-defaults) give the precise rules.

Try the deliberately conflicting result:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix merge.conflict
```

This command is expected to fail, naming `editor.command` and the shared/chosen editor units. When changing the data model isn't the right answer, choose a merge policy for that path. The `replaced`, `wholeEditor`, and `deduplicated` bindings in `examples/ownerships-merge/values.nix` make the three choices below. This excerpt is the complete policy-selection region; the linked file above contains its roster, data, and resolver setup.

<!-- excerpt: ../../examples/ownerships-merge/values.nix -->
```nix
  # this profile changes only the conflicting leaf
  replaced = ownerships.mkResolveProfiled {
    profileForPath = path: if path == "editor.command" then "last-wins" else null;
  } roster conflicting context;
  # selecting the parent path replaces the whole editor subtree
  wholeEditor = ownerships.mkResolveProfiled {
    profileForPath = path: if path == "editor" then "last-wins" else null;
  } roster conflicting context;
  # a named profile changes list behavior only for tools
  deduplicated = ownerships.mkResolveProfiled {
    profiles = {
      strict-ordered = strictOrdered;
      unique-tools = strictOrdered // {
        listStrategy = "dedup-union";
      };
    };
    profileForPath = path: if path == "tools" then "unique-tools" else null;
  } roster units context;
```

Evaluate those bindings:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix merge.replaced
nix eval --impure --json --file examples/ownerships-eval.nix merge.wholeEditor
nix eval --impure --json --file examples/ownerships-eval.nix merge.deduplicated
```

`merge.replaced` selects `"last-wins"` only at `editor.command`:

<!-- value: merge.replaced -->
```json
{"editor":{"command":"vim","wrap":true}}
```

`merge.wholeEditor` selects that policy at `editor` instead. The colliding editor attribute set is replaced as a whole, so the result is `{"editor":{"command":"vim"}}`; `wrap` is gone. Choose the narrow path when you intend to preserve neighboring fields.

`merge.deduplicated` uses a custom list profile for `tools`. Its tool list is `["git","ripgrep"]`, and its editor fields match `merge.combined`. The example's custom scalar policy uses Nix equality for these ordinary data values; use the built-in defaults when you need their treatment of functions and derivations. See [merge policies](advanced-reference.md#merge-policies) for the exact configuration and profile-disagreement rules.

## Reuse declarations from files

The [file example](../../examples/ownerships-files/) contains [flake.nix](../../examples/ownerships-files/flake.nix), [units/home/editor.nix](../../examples/ownerships-files/units/home/editor.nix), and [units/system/accounts.nix](../../examples/ownerships-files/units/system/accounts.nix). It imports the two collections with `importUnitSets { dir = ./units; args.editor = "helix"; }`.

The home file is a function receiving that `editor` argument. The system file is a plain unit. `importUnitSets` returns lists under `home` and `system`; the example resolves them with `mkResolve` and `mkResolveSystem` respectively.

```sh
nix eval --impure --json --file examples/ownerships-eval.nix files.home
nix eval --impure --json --file examples/ownerships-eval.nix files.system
```

<!-- value: files.home -->
```json
{"home":{"sessionVariables":{"EDITOR":"helix"}}}
```

<!-- value: files.system -->
```json
{"users":{"users":{"alice":{"isNormalUser":true}}}}
```

The account data uses `value.users` because a unit's top-level `users` is a claim. System-scope units can narrow by host and predicate, but `users` and `exceptUsers` claims are errors, including inside children.

For a single collection, `importUnits { dir = ./units; }` returns a list directly. The [worked example](worked-example.md) also passes a reusable declaration function through `args`. Imports are ordered by relative file path; individual files can return one unit or a list. Keep unrelated files out of the import directory, particularly helper `.nix` files that don't return units.

## Use the result in a module

The file example returns data shaped like Home Manager and NixOS settings. To use that data, pass it as a module's `config` inside an actual Home Manager or NixOS configuration. That surrounding configuration supplies its option definitions and required setup.

The example also makes a small `lib.evalModules` evaluation with just the `home.sessionVariables` option declared. It supplies `EDITOR = lib.mkDefault "vim"` in one module and the selected home data in another:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix files.moduleEditor
```

<!-- value: files.moduleEditor -->
```json
"helix"
```

That priority decision belongs to the Nix module system. Ownerships had already selected the ordinary value `"helix"`; it didn't interpret `mkDefault`. Keep module priorities such as `mkDefault` and `mkForce`, option definitions, and module conditionals in the module evaluation that understands them. Don't assume merging their marker attribute sets as ordinary Ownerships data reproduces those semantics.

This miniature evaluation isn't a full Home Manager setup or a machine to activate. Once the data is right, connect it to your existing configuration and use that configuration's normal validation before activation.

Ready to put these choices together? Continue with [a team's editing preferences](worked-example.md). If a result surprises you first, [inspect the selection](inspection.md).
