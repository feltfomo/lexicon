# theme aggregation. size public theme declarations are combined in one nixos
# module evaluation and the generated matugen registration is demanded. the toml
# generator is replaced with a json capture, so this measures pure aggregation
# without a renderer build
{
  api,
  lib,
  pkgs,
  names,
  fixtures,
  ...
}:
let
  target = {
    host = {
      name = "host";
      system = "x86_64-linux";
    };
    user.name = "user";
  };

  themes = map (
    name:
    (api.lexicon.forTarget { inherit target; } {
      theme = {
        id = name;
        renderers.dms = {
          source = fixtures + "/directory/safe-render.nix";
          output = ".output/${name}";
        };
      };
    }).nixos
  ) names;

  # the host options the theme runtime writes, declared as loosely as possible
  # so the measurement is lexicon's aggregation and not nixos option checking
  host =
    { lib, ... }:
    let
      option =
        type: default:
        lib.mkOption {
          inherit type default;
        };
    in
    {
      options = {
        assertions = option (lib.types.listOf lib.types.attrs) [ ];
        systemd.services = option lib.types.attrs { };
        networking.hostName = option lib.types.str "host";
        system.activationScripts = option lib.types.attrs { };
        system.extraDependencies = option (lib.types.listOf lib.types.raw) [ ];
        environment.systemPackages = option (lib.types.listOf lib.types.raw) [ ];
      };
    };

  evaluation = lib.evalModules {
    specialArgs.pkgs = pkgs // {
      formats.toml = _: { generate = name: value: builtins.toFile name (builtins.toJSON value); };
    };
    modules = [ host ] ++ themes;
  };

  entries = evaluation.config.lexicon.furnish.declarations;
  registration = builtins.head (
    builtins.filter (entry: entry.destination == ".config/matugen/config.toml") entries
  );
  generated = builtins.fromJSON (builtins.readFile registration.source.value);
in
{
  # source paths are left out because they name each revision's store path
  matugen = {
    destinations = map (entry: entry.destination) entries;
    templates = lib.mapAttrs (_: value: removeAttrs value [ "input_path" ]) generated.templates;
  };
}
