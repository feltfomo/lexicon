# Program theme API

`program` declarations accept a `theme` attribute set. Its accepted fields are
`id`, `templates`, `renderers`, the value fields below and ownership claims.

`id` is required and must be a normalized non-empty basename. Choose either
one inline template or `templates = [ template ... ];`. With `templates`,
the enclosing block cannot also carry template value fields, claims or
`renderers`. Each template requires a non-empty `renderers` attribute set.

## Template and renderer fields

Template defaults are overridden by `renderers.<name>` fields using a shallow
attribute-set merge. Renderer names are `caelestia`, `dms`, `end4-pc`,
`illogical-impulse`, `lucid`, `noctalia`, `serpantinum`.

| Field | Type | Default / meaning |
| --- | --- | --- |
| `source` | Path or string | Required in each effective renderer; template source |
| `output` | Normalized relative path | Required in each effective renderer; rendered output under the user's home |
| `subdir` | Relative directory string, empty string or null | Theme `id`; null or empty means template root, trailing `/` accepted |
| `placedAs` | Normalized basename | Basename of `source`; installed template filename |
| `subId` | Normalized basename or null | null; suffix for a distinct registration |
| `reload` | String or null | null; renderer hook after output changes |
| `merge` | Attribute set | Optional explicit TOML composition, described below |
| `native` | Attribute set | `{}`; additional native registration fields |
| `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when` | Ownership claims | Select this template entry |
| `sharedWith` | List of renderer names | `[]`; only valid inside a renderer override |

`sharedWith` copies the effective renderer settings to each listed backend.
It asserts that the supplied template is suitable for those renderers; it does
not translate template syntax. It rejects unknown names, duplicates, the owning
renderer's own name, and any backend assigned by another renderer in the same
template. Unknown fields and backend names are errors.

Registration ID is `id` when `subId` is null, otherwise `"${id}-${subId}"`.
Multiple templates under one ID generally need distinct `subId` values.
Duplicate registration IDs fail. Matugen renderers check IDs across program
declarations for each renderer, filesystem namespace and principal.

Normalized paths reject leading `/`, empty components, `.` and `..`.
`placedAs`, `subId` and `id` also reject `/`.

## Renderer destinations

| Renderer | Template root under home | Registration / behavior |
| --- | --- | --- |
| `caelestia` | `.config/caelestia/templates` | Templates named `registrationId-placedAs`; `.config/caelestia/theme-hooks/<id>` copies rendered files from `.local/state/caelestia/theme` to `output` and runs `reload` |
| `noctalia` | `.config/noctalia/templates` | `<subdir><placedAs>`; `.config/noctalia/<id>.toml`, table `theme.templates.user` |
| `dms` | `.config/matugen/dms/templates` | `<subdir><placedAs>`; `.config/matugen/config.toml` |
| `end4-pc` | `.config/end4-pc/matugen/templates` | `<subdir><placedAs>`; `.config/end4-pc/matugen/config.toml` |
| `illogical-impulse` | `.config/illogical-impulse/matugen/templates` | `<subdir><placedAs>`; `.config/illogical-impulse/matugen/config.toml` |
| `lucid` | `.config/lucid/matugen/templates` | `<subdir><placedAs>`; `.config/lucid/matugen/config.toml` |
| `serpantinum` | `.config/serpantinum/matugen/templates` | `<subdir><placedAs>`; `.config/serpantinum/matugen/config.toml` |

Template sources are Furnish `writable` files with `onConflict = "runtime-wins"`.
Registration files and Caelestia hooks use ordinary Furnish file defaults.

All renderers except Caelestia accept `native`. Generated `input_path` and
`output_path` override native fields with the same names; a supplied `reload`
overrides native `post_hook`. Noctalia registrations use `~/` paths. Matugen
registrations use absolute home paths and combine templates into one config per
renderer and principal. These APIs register templates; they do not install,
enable or invoke the desktop shell or renderer.

Theme file preparation uses the shared native Checked computation. Registration
collisions and unsupported native fields are checked before adapter output is
constructed. Each demanded file group retains its own `checked` failure terminal.
A throwing terminal stops demand before later groups; a recovering terminal's file
list participates in concatenation. Successful groups don't call `checked` or
`finish`. Generated sources stay lazy until a file source is demanded. Matugen
keeps one `finish` call per renderer/principal group and demands its return before
constructing declarations, preserving each entry's original principal.

## Composed TOML outputs

A template or renderer can opt into explicit composition:

```nix
theme = {
  id = "app";
  output = ".config/app/config.toml";
  merge = {
    format = "toml";
    base = {
      onboarding = false;
      keys.command = [ { key = "prefix+f"; command = "find-pane"; } ];
    };
    conflict = "error";
    arrays = "replace";
  };
  renderers.noctalia.source = ./palette.toml;
};
```

The template contains only theme values. `merge.base` accepts Nix attributes,
a `toml.document`, or an explicit generated TOML file. The standalone builder
and merge policies are documented in `src/toml/reference.md`. `merge` accepts
only `format`, `base`, `conflict` and `arrays`. Unsupported formats and policies
fail at evaluation. Ownership selection, template defaults and `sharedWith`
apply before composition.

Lexicon redirects each renderer into a private staging file. Its post hook
calls the common publisher, which reads the currently installed descriptor,
merges its base with the rendered palette and atomically replaces `output`.
Caelestia copies into staging before that same publication call. Equivalent
variants across different renderers share one final-file owner and one accepted
palette. Each renderer may provide only one template for that destination;
same-renderer fragments must be combined in their template source. Conflicting
bases, policies, reload commands or principals are errors. Ordinary Furnish
files, links and theme outputs cannot own the same path or an overlapping path.

An explicit `reload` takes precedence over `native.post_hook`. When `reload` is
absent, composition retains the native hook as the application's reload command.
With Furnish disabled, descriptors remain inspectable declarations and no
publisher services are installed.

With Furnish enabled, a system oneshot service publishes each composed output
under its user's identity after Furnish and destination mounts. Descriptor
changes restart that service on configuration switches. Boot also runs it.
The first publication has only the base if no palette has been accepted yet;
the application can use its default colors until the next theme event. Later
rebuilds reuse the last accepted palette across renderer variants. They don't
read the old final application config, so removed base settings stay removed.
No daemon, watcher, Home Manager activation or wallpaper event is required.

For each participating home, `.local/state/lexicon/toml` is reserved for the
publisher's locks, staging files, accepted palettes and reload markers. Composed
outputs, ordinary theme outputs and Furnish file/link claims cannot overlap that
directory or own an ancestor of it.

The final file belongs to the publisher, not Furnish. Furnish installs the
immutable current descriptor and renderer templates. Its existing retirement
rules still apply to those inputs. Removing a composed declaration leaves the
runtime output and accepted palette in place; Lexicon doesn't delete user files
when retiring a publisher. A later declaration at that path reuses its palette.

Publication locks each output and validates the complete merge before writing.
It retains an existing regular file's mode, or creates a new file with mode
0600. Symlink and nonregular destinations are rejected. Unchanged bytes skip
both writes and reloads. A valid theme is durably cached before replacing the
final file; after an interruption, the next call regenerates the final file
from the current base and accepted palette. A failed reload leaves a pending
marker and the next call retries it even if the output bytes already match.
Invalid themes, malformed caches and I/O errors fail visibly. A new valid theme
can replace a malformed cache. Failed validation leaves the final file intact.
Reload commands run as the selected user with a normal runtime-directory and
session-bus fallback derived from that process's UID. Use closure-resolved
binaries and guard only application-specific absence conditions if a cold boot
has no running application to reload.
