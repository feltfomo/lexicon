# Publish files and directories

Program's file features are the application-oriented layer over Furnish. You provide application-relative sources and destinations; Program derives the bound namespace, authority, managed root, source shape, and declaration identity.

File-producing declarations emit `nixos` even when they have no explicit `nixos` field. Import that output into the NixOS graph. Set `lexicon.furnish.enable = true` when the host should reconcile the generated declarations. Evaluation and build-only checks do not write destinations.

## Publish one file

The focused example is a files-only declaration:

<!-- source: ../../examples/program-files/files.nix -->
```nix
{ program }:
program {
  files = [
    {
      # program supplies namespace, authority, managed root, and source shape to Furnish
      dest = ".config/paperkite/settings.conf";
      src = ./sources/settings.conf;
    }
  ];
}
```

```sh
nix eval --impure --json --file examples/program-eval.nix files.file
```

<!-- program-value: files.file -->
```json
{
  "furnishEnabled": true,
  "manifest": [
    {
      "destination": "/home/river/.config/paperkite/settings.conf",
      "onConflict": "error",
      "representation": "symlink"
    }
  ],
  "outputs": ["nixos"],
  "serviceEnabled": true
}
```

The direct binding defaults the user home to `/home/river`, so Furnish's compiled destination is absolute. Program defaults `representation` to `"symlink"`. Omitting `onConflict` lets Furnish supply `"error"` in the manifest.

Optional file fields refine diagnostics and lifecycle behavior:

- `label` replaces the generated declaration label `files[<dest>]`.
- `provenance` is a source-description string; Program passes it to Furnish as provenance source metadata.
- `representation` accepts the supported Furnish capabilities, currently `"symlink"` or `"writable"`.
- `onConflict` accepts `"error"`, `"source-wins"`, or `"runtime-wins"`.

Use `"symlink"` for immutable configuration tied to a retained source artifact. Use `"writable"` only when the application is expected to edit the destination. For a writable file, choose a conflict policy according to whether a two-sided change should stop, replace the runtime edit, or preserve it. The [Furnish usage guide](../furnish/usage.md) explains the lifecycle semantics in detail.

## Expand a directory

A directory entry walks a source tree and preserves each regular file's relative name beneath `dest`:

<!-- source: ../../examples/program-files/directory.nix -->
```nix
{ program }:
program {
  directories = [
    {
      src = ./sources/snippets;
      dest = ".config/paperkite/snippets";
      exclude = [ "draft.conf" ];
      files = [
        {
          names = [ "notes.conf" ];
          # runtime edits are intentional for the writable notes file
          representation = "writable";
          onConflict = "runtime-wins";
          provenance = "examples/program-files/directory.nix";
        }
      ];
    }
  ];
}
```

```sh
nix eval --impure --json --file examples/program-eval.nix files.directory
```

<!-- program-value: files.directory -->
```json
{
  "manifest": [
    {
      "destination": "/home/river/.config/paperkite/snippets/notes.conf",
      "onConflict": "runtime-wins",
      "representation": "writable"
    },
    {
      "destination": "/home/river/.config/paperkite/snippets/shortcuts.conf",
      "onConflict": "error",
      "representation": "symlink"
    }
  ],
  "outputs": ["nixos"]
}
```

`draft.conf` exists in the source but is excluded. `shortcuts.conf` inherits the directory defaults. The `names = [ "notes.conf" ]` rule reserves that member and applies the narrower writable policy.

## Directory rules

A directory may set lifecycle fields once and override them for named files:

- `src` is a path or string naming a readable directory.
- `dest` is the destination root.
- `exclude` lists normalized relative file or subtree names.
- `files` contains focused rules.
- `representation`, `onConflict`, and `provenance` become defaults for expanded members.

Each rule requires a nonempty `names` list. The listed names must exist in the source inventory, must not be excluded, and must not repeat a name reserved by another rule. A rule overrides only lifecycle fields present on that rule; other lifecycle settings continue to come from the directory.

An exclusion names either one member or a whole subtree. Unknown exclusions fail rather than silently matching nothing. Special filesystem members are rejected; directory expansion accepts regular files and directories.

When a theme template points inside the same declared source tree, Program reserves that source from ordinary directory publication. Excluding or separately overriding the themed source is an error. This prevents one source from being published both as a plain file and as renderer input.

## Selection and direct targets

Direct mode rejects Program claim fields on files, directories, and directory rules. Use [Ownerships-backed Program](ownerships.md) when a file set must select hosts or users.

With `programDirect`, every file-producing capability requires `target.user`. Its name supplies user authority; its explicit or default home supplies the managed traversal root. A host-only direct binding remains valid for package-only, Home Manager import-only, and NixOS-only declarations, but it fails when a file feature is forced.

The exact nested fields and failure conditions are in the [reference](reference.md#files) and [directory reference](reference.md#directories-and-rules).

[Program contents](README.md) · [Themes](themes.md) · [Worked example](worked-example.md)
