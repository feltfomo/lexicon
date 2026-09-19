# Your first Ownerships result

Let's select an editor preference for Alice on a fictional laptop. You'll evaluate a value, change the preference, and evaluate it again. Nothing will be installed or activated.

If you haven't prepared Nix and a Lexicon checkout, follow [preparation](../preparation.md). Keep your terminal at the repository root throughout this lesson.

## Open the example

Open `examples/ownerships-minimal/flake.nix` in your editor. It already exists in the checkout. This is the complete file; it has no companion configuration files:

<!-- source: ../../examples/ownerships-minimal/flake.nix -->
```nix
{
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { lexicon, ... }:
    let
      ownerships = lexicon.lib.ownerships { };
      # the roster bounds which host and user names can be resolved
      roster = ownerships.toRoster [
        (ownerships.define.host "laptop")
        (ownerships.define.user "alice" { hosts = [ "laptop" ]; })
      ];
      units = [
        {
          users = [ "alice" ];
          editor = "helix";
        }
      ];
    in
    {
      # resolution needs both host and user context even for one matching unit
      lib.result = ownerships.mkResolve roster units {
        host.name = "laptop";
        user.name = "alice";
      };
    };
}
```

`lexicon.lib.ownerships { }` creates the library value used by the example. The empty argument set selects its default dependencies and ownership rules.

The **roster** names the hosts and users we know about. Alice's `hosts` field records membership on the laptop. It describes this example; it doesn't create an operating-system account.

Inside `units`, the attribute set is a **unit**: one piece of configuration. `users = [ "alice" ]` is its **claim**, selecting who gets that piece. The `editor` field is the data we want back.

The last argument to `mkResolve` is the **context**, the user and host we're asking about now. With this roster, unit, and context, Alice's preference applies.

## Evaluate it

From the repository root, run:

```sh
nix eval --impure --json --file examples/ownerships-eval.nix minimal.result
```

The supplied runner uses this checkout's library and the complete file above. It prints:

<!-- value: minimal.result -->
```json
{"editor":"helix"}
```

If you see an experimental-feature or dependency-fetch error, return to [Check Nix](../preparation.md#check-nix). If you see a syntax error after editing, compare the file with the complete listing above; Nix assignments need their trailing semicolons.

## Make a change

In that same file, change `editor = "helix";` to `editor = "vim";`, save it, and run the same command again. You'll get:

<!-- value: minimal.changed -->
```json
{"editor":"vim"}
```

You've changed the data in a unit, not the selection. The claim still names Alice, and the context still asks for Alice on the laptop. Restore `"helix"` when you're done so the checked-in example and its expected result agree.

## Use the result in a separate flake

The first exercises use the source and dependencies in your checkout. A normal consumer project resolves Lexicon through its own flake instead.

From the directory where you keep projects, create a new directory and enter it:

```sh
mkdir ownerships-demo
cd ownerships-demo
```

While you're in `ownerships-demo`, save the complete file from [the example](../../examples/ownerships-minimal/flake.nix) as `flake.nix`. That's the only file this result needs. Don't copy `ownerships-eval.nix`, `ownerships-suite.nix`, or anything from `tests`.

The `inputs.lexicon.url` declaration selects Lexicon. The `outputs` function receives that input and publishes the selected value as `lib.result`. Still in `ownerships-demo`, evaluate that output through the flake interface:

```sh
nix eval --json .#lib.result
```

<!-- value: minimal.result -->
```json
{"editor":"helix"}
```

On the first run, Nix resolves the input and creates `flake.lock` if it isn't present. Later evaluations use those locked revisions. Running `nix flake update` or changing an input declaration can update the lock; review and keep that file with the project when you want reproducible results.

For an existing flake, add `lexicon.url` beside its current inputs, add `lexicon` to the existing `outputs` argument set, and add the Ownerships value beside the outputs already returned. Don't replace the input set, the `outputs` function, or an existing `lib` attribute; extend each one at its current definition.

Next, [add another user and host](usage.md#choose-settings-for-more-people-and-machines). That example shows a claim leaving a unit out of the result, and multiple matching units contributing together.
