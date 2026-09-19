# A team's editing preferences

Alice, Sam, and Robin share editing tools across a workstation and a laptop. They need common defaults, individual editors, review tools for the people doing prose review, and a few settings for the smaller mobile machine. We'll keep the result as data so each choice stays visible.

The [complete example](../../examples/ownerships-team/) uses only Ownerships. Run its commands from the Lexicon root after [preparation](../preparation.md).

## Read the configuration

| File | What to look for |
| --- | --- |
| [flake.nix](../../examples/ownerships-team/flake.nix) | Declares the Lexicon input and exposes the example's values. |
| [roster.nix](../../examples/ownerships-team/roster.nix) | Alice belongs to both hosts, Sam to the workstation, and Robin to the laptop. |
| [team.nix](../../examples/ownerships-team/team.nix) | Supplies the factory, import arguments, contexts, and evaluated results. |
| [units/00-common.nix](../../examples/ownerships-team/units/00-common.nix) | Git, Ripgrep, line numbers, and a tab width shared by the team. |
| [units/10-editors.nix](../../examples/ownerships-team/units/10-editors.nix) | Reuses `editorFor` to declare a preference for each person. |
| [units/20-review.nix](../../examples/ownerships-team/units/20-review.nix) | Gives Alice and Robin review tools, with a nested laptop wrapping setting. |
| [units/30-mobile.nix](../../examples/ownerships-team/units/30-mobile.nix) | Enables a shorter autosave interval when `host.mobile` is true. |

Those are all the example files. `importUnits` reads the unit directory in relative-path order, so the numbered filenames also make contribution order easy to see. `team.nix` creates the library and passes the reusable `editorFor` function through the importer's `args`.

The `editorFor` binding in `examples/ownerships-team/team.nix` is an ordinary Nix function, `user: command: unit`. This excerpt shows the reusable declaration; the complete file remains linked in the table above.

<!-- excerpt: ../../examples/ownerships-team/team.nix -->
```nix
  editorFor = user: command: {
    label = "${user}'s editor";
    users = [ user ];
    editor.command = command;
  };
```

Each call produces an editor unit with its own user claim and readable label. The claim controls selection, while the label identifies that contribution during inspection.

The top-level unit in `examples/ownerships-team/units/20-review.nix` is the review parent. This excerpt shows its claims and child; use the table link for the complete file.

<!-- excerpt: ../../examples/ownerships-team/units/20-review.nix -->
```nix
  hosts = [
    "workstation"
    "laptop"
  ];
  users = [
    "alice"
    "robin"
  ];
  tools = [ "typos" ];
  review.language = "en";
  # the child can only narrow the reviewer and host claims above
  children = [
    {
      label = "review on a small screen";
      hosts = [ "laptop" ];
      editor.wrap = true;
    }
  ];
```

The parent gives Alice and Robin the review tool and language on both hosts. Its child narrows that same group to the laptop before adding wrapping. Sam's editor preference still applies on the workstation without picking up the review settings.

## Compare the results

```sh
nix eval --impure --json --file examples/ownerships-eval.nix team.alice
nix eval --impure --json --file examples/ownerships-eval.nix team.sam
nix eval --impure --json --file examples/ownerships-eval.nix team.laptop
nix eval --impure --json --file examples/ownerships-eval.nix team.robin
```

Alice on the workstation:

<!-- value: team.alice -->
```json
{"editor":{"command":"helix","lineNumbers":true,"tabWidth":2},"review":{"language":"en"},"tools":["git","ripgrep","typos"]}
```

Sam on the workstation:

<!-- value: team.sam -->
```json
{"editor":{"command":"vim","lineNumbers":true,"tabWidth":2},"tools":["git","ripgrep"]}
```

On the laptop, Alice and Robin both receive:

<!-- value: team.laptop -->
```json
{"editor":{"autosaveSeconds":30,"command":"helix","lineNumbers":true,"tabWidth":2,"wrap":true},"review":{"language":"en"},"tools":["git","ripgrep","typos"]}
```

The lists accumulate without duplicate tool entries here because the declarations contribute different tools. The editor attribute sets add fields at distinct paths, so ordinary strict merging is enough. There's no need for a last-wins policy in this configuration.

`team.nix` binds a prepared resolver once for the shared units, then calls it for each context. That's useful when the number of evaluated host/user combinations grows. The matching, errors, and merge defaults are the same as in the earlier examples.

## Change one choice

In `units/10-editors.nix`, change Sam's editor from `"vim"` to `"helix"` and evaluate `team.sam` again. Only `editor.command` changes. Alice and Robin keep their existing results. Restore the original after trying it.

For a larger change, add a new person to `roster.nix`, give them explicit host membership, add an `editorFor` declaration, and expose a corresponding result in `team.nix`. Decide whether they belong in the review claim rather than letting a copied block decide for you. The [roster reference](reference.md#declare-a-roster) covers known, unknown, and empty membership.

## Check where the review settings land

```sh
nix eval --impure --json --file examples/ownerships-eval.nix team.matrix.coverage.preMerge.paths.review
```

<!-- value: team.matrix.coverage.preMerge.paths.review -->
```json
["x86_64-linux/workstation/alice","x86_64-linux/laptop/alice","x86_64-linux/laptop/robin"]
```

The matrix receives a `contextFor` function that supplies the same mobile property used by normal evaluation. Otherwise a predicate depending on that property would describe a different question. Read [inspection](inspection.md) for tracing one result or checking unused declarations.

This is the end of the Ownerships learning path. Keep these values as data, or use the [module guidance](usage.md#use-the-result-in-a-module) when adapting them to your own configuration.
