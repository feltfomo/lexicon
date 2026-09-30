{
  lib,
  pkgs,
  lexicon,
  ...
}:
let
  direct = lexicon.lib.programDirect {
    target = {
      host = {
        name = "workstation";
        system = pkgs.stdenv.hostPlatform.system;
      };
      user = {
        name = "alice";
        home = "/srv/alice";
      };
    };
  };
  aspect = direct {
    theme = {
      id = "editor";
      source = ./fixtures/sample-tree/safe-render.nix;
      output = ".config/editor/palette";
      reload = "editor-reload";
      renderers.illogical-impulse.sharedWith = [ "serpantinum" ];
    };
  };
  second = direct {
    theme = {
      id = "terminal";
      templates = [
        {
          subId = "colors";
          renderers.serpantinum = {
            source = ./fixtures/sample-tree/safe-render.nix;
            output = ".config/terminal/colors";
            native.compare_to = "dark";
          };
        }
      ];
    };
  };
  # Capture the generated configuration before serialization; the renderer
  # contract is the destination, registration fields and principal's home.
  evaluation = lib.evalModules {
    specialArgs.pkgs = pkgs // {
      formats.toml = _: {
        generate = name: value: builtins.toFile name (builtins.toJSON value);
      };
    };
    modules = [
      ({ lib, ... }: {
        options = {
          networking.hostName = lib.mkOption {
            type = lib.types.str;
            default = "workstation";
          };
          assertions = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
          };
          system.extraDependencies = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          environment.systemPackages = lib.mkOption {
            type = lib.types.listOf lib.types.raw;
            default = [ ];
          };
          system.activationScripts = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          systemd.services = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        };
      })
      aspect.nixos
      second.nixos
      (direct {
        theme = {
          id = "dms-editor";
          renderers.dms = {
            source = ./fixtures/sample-tree/safe-render.nix;
            output = ".config/editor/dms-palette";
          };
        };
      }).nixos
      (direct {
        theme = {
          id = "lucid-editor";
          renderers.lucid = {
            source = ./fixtures/sample-tree/safe-render.nix;
            output = ".config/editor/lucid-palette";
          };
        };
      }).nixos
    ];
  };
  declarations = evaluation.config.lexicon.furnish.declarations;
  configs = builtins.filter (
    entry: entry.destination == ".config/serpantinum/matugen/config.toml"
  ) declarations;
  generated = builtins.fromJSON (builtins.readFile (builtins.head configs).source.value);
  inherit (generated) templates;
  seed = builtins.head (
    builtins.filter (
      entry: entry.destination == ".config/serpantinum/matugen/templates/editor/safe-render.nix"
    ) declarations
  );
in
{
  serpantinum-config-does-not-collide-with-dms-or-lucid =
    builtins.length (
      builtins.filter (entry: entry.destination == ".config/matugen/config.toml") declarations
    ) == 1
    &&
      builtins.length (
        builtins.filter (entry: entry.destination == ".config/lucid/matugen/config.toml") declarations
      ) == 1;
  serpantinum-shared-templates-use-writable-seeds =
    seed.representation == "writable" && seed.onConflict == "runtime-wins";
  serpantinum-registrations-aggregate-across-programs =
    builtins.length configs == 1
    &&
      builtins.attrNames templates == [
        "editor"
        "terminal-colors"
      ];
  serpantinum-registrations-use-managed-home-and-reload =
    templates.editor == {
      input_path = "/srv/alice/.config/serpantinum/matugen/templates/editor/safe-render.nix";
      output_path = "/srv/alice/.config/editor/palette";
      post_hook = "editor-reload";
    };
  serpantinum-native-fields-and-subids-survive =
    templates.terminal-colors == {
      input_path = "/srv/alice/.config/serpantinum/matugen/templates/terminal/safe-render.nix";
      output_path = "/srv/alice/.config/terminal/colors";
      compare_to = "dark";
    };
}
