# Produce theme files

A Program theme takes one or more template sources and lowers them into files and renderer registrations. A theme with an effective renderer is file-producing, so a theme-only declaration emits `nixos`, imports the required Furnish integration, and requires a bound user.

## Start with one renderer

The focused example registers one template with Noctalia:

<!-- source: ../../examples/program-themes/theme.nix -->
```nix
{ program }:
program {
  theme = {
    id = "paperkite";
    renderers.noctalia = {
      source = ./palette.tmpl;
      output = ".config/paperkite/colors.conf";
      # native fields become renderer-specific registration data
      native.compare_to = "dark";
    };
  };
}
```

`id` names the theme block and contributes to registration and template paths. `source` is the template file. `output` is the home-relative file the renderer should produce. The renderer-specific `native` attribute set is copied into Noctalia's registration data.

The NixOS configuration imports `theme.nixos` even though the declaration has no explicit `nixos` field:

<!-- source: ../../examples/program-themes/configuration.nix -->
```nix
{ theme }:
{
  # a file-producing theme emits the NixOS side even without a nixos field
  imports = [ theme.nixos ];
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

Evaluate its checked destinations from the Lexicon root:

```sh
nix eval --impure --json --file examples/program-eval.nix themes.result
```

<!-- program-value: themes.result -->
```json
{
  "destinations": [
    "/home/river/.config/noctalia/paperkite.toml",
    "/home/river/.config/noctalia/templates/paperkite/palette.tmpl"
  ],
  "furnishEnabled": true,
  "outputs": ["nixos"]
}
```

The template seed is writable with `runtime-wins`, because the renderer consumes and may update working template state. The registration file is generated separately. Program supplies both as Furnish declarations; the application author does not write raw declarations.

## Single-template and template-list forms

The focused example uses the single-template form: `id` and `renderers` are on `theme`, while template value fields may be inherited by each renderer override.

Use `theme.templates` for multiple template registrations under one `id`:

```nix
program {
  theme = {
    id = "paperkite";
    templates = [
      {
        subId = "terminal";
        renderers.noctalia = {
          source = ./terminal.tmpl;
          output = ".config/paperkite/terminal.conf";
        };
      }
      {
        subId = "editor";
        renderers.noctalia = {
          source = ./editor.tmpl;
          output = ".config/paperkite/editor.conf";
        };
      }
    ];
  };
}
```

Do not mix `templates` with single-template fields on the same `theme` object. Each template must provide a nonempty `renderers` set, and each effective renderer entry must have `source` and `output` after inherited values and overrides are combined.

## Placement fields

Template values have these placement defaults:

- `subdir` defaults to the theme `id`. `null` or `""` places the template directly under the renderer's template root; another value must be a normalized relative directory.
- `placedAs` defaults to the source basename and must remain one basename.
- `subId` defaults to `null`. When present, Program joins it to `id` for a distinct registration key.
- `reload` defaults to `null`; a string becomes the renderer's post-render action where that backend supports one.
- `native` defaults to `{ }` and carries backend-specific registration data.

Duplicate registration IDs fail. Relative fields reject empty path components, `.` components, `..` traversal, and absolute paths.

## Renderer backends

Program currently recognizes five renderer names:

| Renderer | Template behavior | Registration behavior |
| --- | --- | --- |
| `noctalia` | Publishes writable seeds below `.config/noctalia/templates` | Generates one TOML registration file per theme block; supports `native` fields |
| `caelestia` | Publishes writable seeds below `.config/caelestia/templates` | Generates one strict theme-hook script per block; `native` fields are rejected |
| `dms` | Publishes writable Matugen templates below `.config/matugen/dms/templates` | Aggregates selected entries into the user's Matugen `config.toml`; supports `native` fields |
| `end4-pc` | Publishes writable templates below `.config/end4-pc/matugen/templates` | Aggregates Matugen registration data; supports `native` fields |
| `illogical-impulse` | Publishes writable templates below `.config/illogical-impulse/matugen/templates` | Aggregates Matugen registration data; supports `native` fields |

Matugen itself has no include mechanism. Program therefore collects DMS, end4-pc, and illogical-impulse entries across imported Program modules and generates one renderer-and-user-specific configuration through the NixOS module graph.

## Share a registration

A renderer override may use `sharedWith` to send the same effective source and output to additional known backends:

```nix
renderers.noctalia = {
  source = ./palette.tmpl;
  output = ".config/paperkite/colors.conf";
  sharedWith = [
    "dms"
    "end4-pc"
    "illogical-impulse"
  ];
};
```

Names must be known, unique, and different from the owning renderer. One backend may be assigned by only one renderer declaration in a template; overlapping direct and shared assignments fail. Sharing is direction-independent: the selected owner controls only where the common values are written, not which backend names are valid.

Direct mode rejects claim fields on `theme`, each template, and each renderer override. Use [Ownerships integration](ownerships.md) when renderer entries need host or user selection. Complete field vocabularies and diagnostics are in the [reference](reference.md#themes-templates-and-renderers).

[Program contents](README.md) · [Files and directories](files.md) · [Reference](reference.md)
