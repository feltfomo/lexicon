# Program

Program describes an application's package, modules, managed files, directory
trees, and theme as one aspect. It uses Ownerships to select configuration and
Furnish to install files. Den can place the resulting modules into its aspect
graph, but the application declaration does not need to read Den internals.

## Declare an application

Given a configured `program` factory:

```nix
program {
  pkg = pkgs: pkgs.helix;
  files = [ {
    src = ./helix/config.toml;
    dest = ".config/helix/config.toml";
  } ];
}
```

This installs Helix through the generated Home Manager module and hands the
file to Furnish through the generated NixOS module. The destination is relative
to the receiving user's home. Provide the source file alongside the declaration.

An aspect may contain only a package, only modules, or only files. You do not
have to fill every section.

## Bind the integration once

The public factory is `inputs.lexicon.lib.program`. Supply Ownerships resolvers
and your integration's principal projection:

```nix
program = inputs.lexicon.lib.program {
  inherit lib;
  resolve = doors.resolve;
  resolveSystem = doors.resolveSystem;
  resolvePrepared = doors.prepared;
  inherit filePrincipals hostUserNames;
};
```

Here `doors = ownerships.mkResolvers roster`. `filePrincipals` maps the receiving
context to Furnish user principals, including authority identity and managed
home root. `hostUserNames` reports the host's configured users for diagnostics.
A Lexicon Den adapter can provide these bindings; a standalone integration can
provide its own. The public factory supplies Axiom, Krisis, and the coordinator
dependency unless explicitly overridden.

The result of `program { ... }` has `homeManager` when package/import content is
needed, and `nixos` when system slices or files are needed. Import those modules
in the corresponding module system and provide their host/user context. With
Den, assign the result to `den.aspects.<name>` and let Den place the modules.

## Restrict an aspect or an entry

Ownerships claims can apply to the entire declaration or to individual entries:

```nix
program {
  hosts = [ "workstation" "laptop" ];
  pkg = pkgs: pkgs.helix;
  files = [
    { src = ./helix/config.toml; dest = ".config/helix/config.toml"; }
    {
      users = [ "alice" ];
      src = ./helix/alice-languages.toml;
      dest = ".config/helix/languages.toml";
    }
  ];
}
```

An entry narrows the enclosing claim; it cannot expand the aspect onto another
host. `hosts`, `users`, `exceptHosts`, `exceptUsers`, and `when` have their
[Ownerships meanings](ownerships/reference.md). Inactive payloads stay lazy.

## NixOS and Home Manager modules

`imports` contains Home Manager imports. `nixos` accepts one slice, a list, or a
function receiving `pkgs`, `config`, `host`, and `user`:

```nix
program {
  hosts = [ "workstation" "laptop" ];
  nixos = { pkgs, ... }: [
    { environment.systemPackages = [ pkgs.git ]; }
    { hosts = [ "workstation" ]; services.openssh.enable = true; }
  ];
}
```

System slices inherit the aspect's system-applicable claims. A user claim does
not turn a system option into a per-user option. Keep user configuration in
Home Manager or user-owned file entries.

## Files that an application edits

File entries accept `src`, `dest`, optional `label`, ownership claims, and
Furnish lifecycle fields:

```nix
{
  src = ./terminal/config;
  dest = ".config/terminal/config";
  representation = "writable";
  onConflict = "runtime-wins";
  provenance.source = "applications/terminal.nix";
}
```

Omitted representation means `symlink`. Use `writable` when the application
needs a real file. Choose `error`, `source-wins`, or `runtime-wins` based on who
owns later changes; see [Furnish usage](furnish/USAGE.md).

## Directory trees

A directory entry expands files beneath a source directory:

```nix
directories = [ {
  src = ./fish;
  dest = ".config/fish";
  exclude = [ "README.md" ];
  files = [ {
    names = [ "fish_variables" ];
    representation = "writable";
    onConflict = "runtime-wins";
  } ];
} ];
```

The named files must exist in the source tree. `exclude` and override `names`
use normalized relative paths. A name cannot be both excluded and overridden,
repeated in override rules, or separately owned by the theme. Per-file rules
can carry ownership claims and override lifecycle defaults from the directory.

Directory structure is inspected once per aspect, then the selected entries
are expanded for each receiving principal. An unknown override is an error,
not an ignored request.

## Themes

A theme has an `id` and either one inline template or a `templates` list. Do not
mix those forms. Theme destinations participate in the same file-ownership
checks as directory entries, so do not declare the same output twice.

Matugen-backed templates retain their user context and are combined for the
per-user renderer. Program describes the templates; the runtime performs the
rendering and Furnish handles the generated files.

## Declaration fields

| Field | Shape |
| --- | --- |
| Ownership claims | Same fields as Ownerships |
| `pkg` | Function from `pkgs` to one package |
| `imports` | List of Home Manager imports |
| `nixos` | Slice, list of slices, or function returning slices |
| `files` | List of source/destination entries |
| `directories` | List of source trees and per-file rules |
| `theme` | Theme ID and template declaration |

Unknown fields produce a diagnostic, with a spelling suggestion when one is
available. If an aspect produces files but no user principal receives them,
the assertion lists the host's users. Check the outer claim, entry claims, and
principal projection rather than broadening the managed root.

## Source layout

`src/program.nix` composes the emitters. `program/spec.nix` validates declarations;
`fields.nix` defines shared vocabulary; `units.nix` constructs ownership units;
`directories.nix` expands trees; `theme/` compiles templates. `report.nix` applies
diagnostic policy using Krisis. These boundaries keep application declaration,
ownership selection, and file reconciliation separate.
