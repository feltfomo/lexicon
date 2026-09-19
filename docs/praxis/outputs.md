
Everything up to this page ran through the installed `praxis` dispatcher, which is how you run your own project commands. This page is about a different audience: the people and machines that do not have Praxis installed and still need to run them.

- a contributor, reviewer, or someone who just cloned the repository runs one of your commands with a single line and no installation;
- continuous integration runs the same commands you run by hand, through `nix flake check`;
- another flake depends on one of your commands as an ordinary package or app.

The middle one needs a clarification, because Nix already gives you flake checks and Praxis does not make them easier to write. What `checks = [ "your-test-command" ]` buys is that the published check runs the declaration you already wrote, instead of a second copy of it that can drift. Add `root = ./.;` when that command reads your project's files.

Nothing here changes how you run your own commands, and none of it is required.

## One declaration, two audiences

| Surface | What it is | Who uses it |
| --- | --- | --- |
| The `praxis` flake output | The declaration itself, reevaluated on every invocation | You, through the installed `praxis` dispatcher |
| `lexicon.lib.praxis` | A function that turns that declaration into packages, apps, checks, and an optional development shell | Anyone running `nix build`, `nix run`, or `nix flake check` |

Nothing about a command changes when you publish it. The command is the same; publishing only adds doors into it.

Which surface evaluates a declaration decides which of its fields do anything. Commands, tasks, and parameters are read by both. Four fields — `checks`, `perCommand`, `wrappers`, and `devShell` — are *publish-time fields*, read only while `lexicon.lib.praxis` compiles the declaration. The installed dispatcher reads your `praxis` output for its command manifest and never reaches them; because they are valid fields it reports nothing when they are set, so `wrappers = true;` in a project that only exposes a `praxis` output changes nothing at all. `check` is the exception, because it adds a command to the declaration itself, which both surfaces read.

## The project flake

One flake can serve both audiences. `examples/praxis-publish` binds the declaration once and uses it twice:

<!-- source: ../../examples/praxis-publish/flake.nix -->
```nix
{
  description = "Praxis commands published as flake outputs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # one declaration, written once and used by both surfaces below
      declaration = {
        commands.greet = [
          "${pkgs.coreutils}/bin/printf"
          "hi from praxis\n"
        ];
        # publish-time fields: read while lexicon.lib.praxis compiles this
        # declaration, ignored by the installed command
        perCommand = true;
        checks = [ "greet" ];
      };
      published = lexicon.lib.praxis ({ inherit pkgs; } // declaration);
    in
    published.flake
    // {
      # the installed dispatcher reads this output; the published packages,
      # apps, and checks serve everyone who does not have Praxis installed
      praxis = _: declaration;
    };
}
```

`lexicon.lib.praxis` takes the declaration plus a `pkgs`, because it has to build something now rather than at invocation time. `published.flake` is a ready-made set of system-indexed outputs — `packages.x86_64-linux`, `apps.x86_64-linux`, `checks.x86_64-linux`, and `devShells.x86_64-linux.default` when that switch is on — so it can be merged straight into the flake's outputs.

`praxis = _: declaration;` keeps the installed dispatcher working in this project. That output must be a function, because Praxis calls it with `pkgs`, `root`, and `inputs`; this declaration already has the `pkgs` it needs from the `let`, so it discards the argument with `_`. Without this line the project would publish packages while `praxis greet` reported that the flake exposes no `praxis` output.

## The same command, three doors

You run the command the way you always have:

<!-- praxis-command: publish.greet -->
```sh
praxis --quiet greet
```

<!-- praxis-output: publish.greet -->
```text
hi from praxis
```

Someone with nothing installed runs the same command through the published dispatcher:

<!-- praxis-command: publish.visitor -->
```sh
nix run .#praxis -- --quiet greet
```

<!-- praxis-output: publish.visitor -->
```text
hi from praxis
```

No installation happened. Nix fetched the flake, built the dispatcher once, ran `greet` through it, and left nothing behind but a build in the store.

Because this declaration sets `perCommand = true;`, one command can also be reached on its own, without naming the dispatcher at all:

<!-- praxis-command: publish.percommand -->
```sh
nix run .#greet
```

That prints the same line. A per-command app is the single command and nothing else, so it takes no dispatcher flags — `--quiet` and friends belong to `praxis`, not to `greet`. Reach for `perCommand` when something outside your project expects one entry point per action.

The documentation tests build these outputs and run the resulting programs directly, which is why the two outputs above are byte-identical rather than merely claimed to be. `nix run` is the same program, fetched and built on demand.

## Let continuous integration run it

Be clear about what this is and is not. Writing a flake check by hand is already easy — `checks.x86_64-linux.greet = pkgs.runCommand "greet" { } "...";` is a few lines of ordinary Nix, and Praxis has nothing to add to that. What it removes is the *second copy*.

`greet` exists because people run `praxis greet` while they work. `checks = [ "greet" ]` publishes that same declaration as `checks.x86_64-linux.greet`:

```sh
nix flake check
```

The check derivation runs the command through the same runner, from the same compiled manifest, with the same argv, steps, and parameter defaults you get locally. So it cannot drift: when you change what `greet` does, the check changes with it, because there is no separate copy of the command to forget. A hand-written `runCommand` beside a Praxis command is that separate copy.

The corollary is worth stating plainly: if a command is only ever meant for CI and nobody runs it by hand, there is nothing to deduplicate, and a plain `runCommand` is the simpler choice. `checks` earns its place when the command has both audiences.

Eligibility is also decided while the flake evaluates, so a command that could not run unattended is refused with an explanation instead of failing inside a sandbox. That is the subject of the last section on this page.

## Add one switch at a time

Each switch is independent, and every row except `check` is a publish-time field, so it takes effect only on the declaration you hand to `lexicon.lib.praxis`. The "how it is used" column assumes you kept the `praxis = _: declaration;` line from the flake above; the all-switches example below deliberately drops it, so `praxis check` would fail there.

| Switch | What appears | How it is used |
| --- | --- | --- |
| none | `packages.<system>.praxis`, `apps.<system>.praxis` | `nix build .#praxis` builds the dispatcher for this project |
| `perCommand = true;` | `packages.<system>.greet`, `apps.<system>.greet` | One command reached on its own, as shown above |
| `wrappers = true;` | One executable per command inside the main package | `bin/greet` beside `bin/praxis`, with wrapper-aware completions |
| `checks = [ "greet" ];` | `checks.<system>.greet` | `nix flake check` runs the command as a derivation |
| `devShell = true;` | `devShells.<system>.default` | The dispatcher is on `PATH` while that shell is entered |
| `check = true;` | A command named `check`, not an output | `praxis check` runs `nix flake check` |

Two of those deserve a note. Without `wrappers`, the main package is the dispatcher alone; with it, the package also installs a separate executable for each command, which is what you want when another tool expects one binary per action. And `check = true` is the odd one out: it adds a command to your declaration rather than publishing anything, so it is useful whether or not you publish outputs at all.

## Every switch in one flake

`examples/praxis-outputs` turns all of them on at once so the published result can be compared in one place. It is a comparison endpoint, not a starting point: copy the flake earlier on this page instead, and add switches when something actually needs them.

<!-- source: ../../examples/praxis-outputs/flake.nix -->
```nix
{
  description = "Praxis output choices";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # this focused flake enables each output switch for comparison
      published = lexicon.lib.praxis {
        inherit pkgs;
        name = "work";
        commands.unit = [ "${pkgs.coreutils}/bin/true" ];
        check = true;
        checks = [ "unit" ];
        devShell = true;
        perCommand = true;
        wrappers = true;
      };
    in
    published.flake;
}
```

Evaluating that flake lists exactly what it published. This is the offline evaluation the documentation tests run, so the result below is checked rather than described:

<!-- praxis-command: outputs.summary -->
```sh
nix eval --impure --json --file examples/praxis-eval.nix outputs
```

<!-- praxis-value: outputs -->
```json
{"apps":["check","unit","work"],"checks":["unit"],"hasDevShell":true,"packages":["check","unit","work"]}
```

Reading that result against the switches: `work` is the dispatcher, renamed by `name`; `unit` is the per-command output; `check` is the synthesized command, published as an output because `perCommand` is on; `checks` holds the one selected flake check; and the development shell exists. Because this flake returns `published.flake` alone and exposes no `praxis` output, the installed dispatcher cannot run its commands — the flake earlier on this page is the layout to copy if you want both.

Because `wrappers = true;` is set here, the main package carries one executable per command, so a command can be run straight out of that package:

<!-- praxis-command: outputs.wrapper -->
```sh
work unit
```

## Keep `check` and `checks` distinct

The two names look alike and do unrelated things.

| Field | Effect |
| --- | --- |
| `check = true;` | Synthesizes one ordinary command named `check` whose argv runs `nix flake check`. Conflicts with a command or task you already named `check`. |
| `checks = [ "unit" ];` | Selects existing declarations to publish as flake check derivations, run by `nix flake check`. Every selected name must exist. |

A selected name may be a task as well as a command; `checks` resolves against the same merged registry the dispatcher uses, so `checks = [ "verify" ];` works whether `verify` is a command or a task.

A selected check runs unattended in a fresh build directory, so a declaration is refused when it cannot possibly behave that way:

- it prompts, confirms, or marks an action `interactive` — `flake checks cannot contain prompts, terminal requirements or runtime parameter sources`;
- it depends on a fixed location through project `cwd` or an absolute action `cwd` — `flake checks cannot depend on a fixed runtime directory`;
- it needs project files, through root discovery, `requireRoot`, or a script, but the declaration has no `root` — `this flake check needs root = ./. for its source files`.

The last one is the common case, and the fix is one field: `root = ./.;` makes the source available to be copied into the check sandbox. The `source-check` command in [scripts and roots](scripts-and-roots.md) is eligible for exactly that reason. The complete rules are in the [reference](reference.md#flake-check-eligibility).

## A note on `name`

`name = "work";` renames the published dispatcher, its package, and its app. It does not rename your installed command: the generic package is always invoked as `praxis`, and a project's declaration cannot change that. Set `name` only when a published artifact should carry the project's own vocabulary.

Continue with [optional Ownerships selection](ownerships.md), or skip it and open the [worked example](worked-example.md).
