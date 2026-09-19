# Use common Program capabilities

A Program declaration may contain one capability or a coherent combination. Its result is sparse: wire only the output names the declaration actually emits.

## Install one Home Manager package

`pkg` is a function. Program calls it with the Home Manager module's `pkgs` and places the one returned package in `home.packages`.

<!-- source: ../../examples/program-capabilities/package.nix -->
```nix
{ program }:
program {
  # pkg is lowered into the bound user's Home Manager package list
  pkg = pkgs: pkgs.hello;
}
```

```sh
nix eval --impure --json --file examples/program-eval.nix capabilities.package
```

<!-- program-value: capabilities.package -->
```json
{
  "outputs": ["homeManager"],
  "package": "hello"
}
```

Package-only Program emits `homeManager` and no `nixos`. Constructing the binding and evaluating this module do not import the Furnish runtime.

## Import Home Manager modules

`imports` is a list of ordinary Home Manager modules:

<!-- source: ../../examples/program-capabilities/imports.nix -->
```nix
{ program }:
program {
  # imports carry ordinary Home Manager module content through untouched
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
}
```

```sh
nix eval --impure --json --file examples/program-eval.nix capabilities.imports
```

<!-- program-value: capabilities.imports -->
```json
{
  "editor": "hx",
  "outputs": ["homeManager"]
}
```

In a Home Manager user module, put the emitted module in `imports`. The larger example makes that graph explicit:

<!-- source: ../../examples/program-studio/home.nix -->
```nix
{ helix, ... }:
{
  # the same declaration's Home Manager side carries its package and imports
  imports = [ helix.homeManager ];
  home.username = "river";
  home.homeDirectory = "/home/river";
  home.stateVersion = "26.05";
}
```

A declaration with both `pkg` and `imports` still emits one `homeManager` output.

## Add ordinary NixOS module content

`nixos` accepts one module attribute set, a list of module values, or a function that returns either shape. Direct mode wraps those values as ordinary NixOS imports.

<!-- source: ../../examples/program-capabilities/nixos.nix -->
```nix
{ program }:
program {
  # users.users is ordinary module content rather than a Program selection claim
  nixos.users.users.river.isNormalUser = true;
}
```

```sh
nix eval --impure --json --file examples/program-eval.nix capabilities.nixos
```

<!-- program-value: capabilities.nixos -->
```json
{
  "furnishRuntime": false,
  "normalUser": true,
  "outputs": ["nixos"]
}
```

This is NixOS-only, so it does not import Furnish. A function-form `nixos` value receives `pkgs`, `config`, and the target's `host` and `user` values. Use it when the module content needs those build arguments; use an attribute set or list otherwise.

## Understand sparse outputs

Program's output follows demand:

| Declaration contains | Output names |
| --- | --- |
| `pkg` or nonempty `imports` | `homeManager` |
| `nixos` | `nixos` |
| nonempty `files` or `directories` | `nixos` with Furnish integration |
| a file-producing `theme` | `nixos` with Furnish integration |
| capabilities from both sides | the union of `homeManager` and `nixos` |
| no capabilities | no outputs |

The empty focused result confirms the last row:

```sh
nix eval --impure --json --file examples/program-eval.nix capabilities.empty
```

<!-- program-value: capabilities.empty -->
```json
{
  "outputs": []
}
```

Do not unconditionally import `result.homeManager` from a NixOS-only declaration or `result.nixos` from a package-only declaration. Organize application files by the capabilities they actually provide, or conditionally collect the outputs before building module lists.

## Choose direct or selected authoring

`programDirect` activates every Program declaration against its one bound target. Program claim keys—`hosts`, `users`, `exceptHosts`, `exceptUsers`, and `when`—are therefore rejected on declarations and nested Program entries. Remove the claim when the application is global to that target. If selection is intended, bind with [`programOwnerships`](ownerships.md).

This restriction applies to Program's own declaration shapes, not to opaque `nixos` module content. `users.users.river` is a normal NixOS option and is not a Program `users` claim.

Files, directories, and file-producing themes need `target.user`, because Program must derive a user authority and managed home. Package-only, Home Manager import-only, and NixOS-only declarations may use a host-only direct target.

Continue with [files and directories](files.md), [themes](themes.md), or the [worked example](worked-example.md). Exact accepted shapes and nested claim boundaries are in the [reference](reference.md).

[Program contents](README.md) · [Getting started](getting-started.md) · [Reference](reference.md)
