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
