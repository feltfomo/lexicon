# Prepare for the Lexicon examples

You'll need a text editor, a terminal, Nix, and a checkout of [Lexicon](https://github.com/feltfomo/lexicon). An existing checkout is fine. Keep its `flake.lock`: it pins the dependencies used by these lessons. Commands below run from the repository root, the directory containing `flake.nix`, `src`, and `examples`.

## Check Nix

On NixOS, Nix is already installed. Elsewhere, follow the [Nix installation instructions](https://nix.dev/install-nix) for your operating system, then open a new terminal. The installer may need administrative access; nothing in this lesson requires activating a system configuration.

```sh
nix --version
nix --extra-experimental-features 'nix-command flakes' eval --json --expr '1 |> (x: x + 1)'
```

The second command should print `2`. Lexicon's dependencies use Nix pipe syntax. If the evaluator says that syntax isn't enabled, retry with the feature named explicitly:

```sh
nix --extra-experimental-features 'nix-command flakes pipe-operators' eval --json --expr '1 |> (x: x + 1)'
```

If neither command prints `2`, install an evaluator that supports the syntax before continuing. Use the probe rather than relying on a version number.

For the remaining commands, enable `nix-command` and `flakes` in your Nix configuration. Add `extra-experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`, preserving any existing settings. If it doesn't exist, create the `~/.config/nix` directory and a `nix.conf` text file inside it. `~` means your home directory, and `.config` is hidden in many file managers. Add `pipe-operators` to that list only if your successful probe required it. Alternatively, keep supplying the matching `--extra-experimental-features` option on each command. See the [Nix feature reference](https://nix.dev/manual/nix/stable/development/experimental-features).

Dependency downloads need network access on first use unless they're already cached. Ownerships examples evaluate data, Furnish and Program lessons inspect or build store results without activation, and Praxis examples perform safe project-local work.

## The few Nix ideas you'll use

Nix expressions describe values. Evaluation computes a value; a build realizes a package or other store output. Here, `nix eval --json` prints the selected data as JSON so you can read it.

| Syntax | Meaning in these examples |
| --- | --- |
| `{ editor = "helix"; }` | An attribute set: named fields with values. Assignments end in semicolons. |
| `[ "git" "helix" ]` | A list. Items are separated by spaces, not commas. |
| `host.name = "laptop";` | A nested field, equivalent to `host = { name = "laptop"; };`. |
| `let x = 2; in x + 1` | Bind a name for the expression after `in`. |
| `x: x + 1` | A function. `f x` calls `f` with `x`. Curried functions take successive arguments, as in `resolve units context`. |
| `{ lexicon, ... }: body` | A function taking an attribute set that must contain `lexicon`; `...` allows additional arguments. |
| `import ./units.nix` | Read and evaluate a Nix file relative to the importing file. A file returning a function still needs its arguments. |
| `inherit lexicon;` | Shorthand for `lexicon = lexicon;` inside an attribute set. |

A **flake** is a project with a `flake.nix` entry point. Its `inputs` name dependencies; its `outputs` function receives them and returns the project's public values. The lesson exposes `lib.result`, an ordinary value. `flake.lock` records exact input revisions, so keep it when sharing a project.

## Open a complete example

Each manual path links to complete project files under `examples`. Follow the commands on the corresponding page from the directory it names. The first Praxis path uses the installed `praxis` command directly; the other paths evaluate the public values named by their lessons.

Continue to [Ownerships](ownerships/getting-started.md), [Furnish](furnish/getting-started.md), [Program](program/getting-started.md), or [Praxis](praxis/getting-started.md).
