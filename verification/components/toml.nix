{
  source,
  size,
  phase,
  bad ? false,
  input ? null,
}:
let
  project = builtins.getFlake source;
  pkgs = project.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  inherit (pkgs) lib;
  toml = project.lib.toml { inherit pkgs; };
  context = "${pkgs.coreutils}/bin/true";
  attrs = builtins.listToAttrs (
    builtins.genList (index: {
      name = "item${toString index}";
      value = {
        count = if bad && index == 0 then (_: null) else index;
        precise = 1.2345678901234567;
        executable = context;
        values = [
          true
          "two"
          3
        ];
        spelling = toml.literal "0x1_0";
      };
    }) size
  );
  axiom = project.inputs.axiom.lib.axiom { inherit lib; };
  inherit
    (import (project.outPath + "/src/dependencies.nix") {
      inherit lib axiom;
      krisisSource = project.inputs.krisis;
    })
    krisis
    ;
  encoder = import (project.outPath + "/src/toml/encode.nix") { inherit lib axiom krisis; };
  encoded = (encoder.document attrs).value;
  generated = toml.generate "measured-${toString size}.toml" attrs;
  prepared = builtins.fromJSON (builtins.readFile input);
  contextual = prepared // {
    value = builtins.mapAttrs (
      _: node:
      node
      // {
        value = node.value // {
          executable = {
            kind = "scalar";
            value = context;
          };
        };
      }
    ) prepared.value;
  };
  rendered = (import (project.outPath + "/src/toml/render.nix")) contextual;
  operations = {
    evaluation = {
      path = toString generated;
      context = builtins.getContext (toString generated);
    };
    build = generated;
    pure = rendered // {
      context = builtins.getContext rendered.text;
      expectedContext = builtins.getContext context;
    };
    input = encoded;
    inherit (toml) package;
    opacity = toString (
      toml.merge "opaque-measurement.toml" {
        sources = [
          (pkgs.runCommand "unread-input.toml" { } ''printf 'generated=true\n' > "$out"'')
          attrs
        ];
      }
    );
    identity = {
      inherit context;
      evaluator = toString pkgs.nix;
      version = pkgs.nix.version;
    };
  };
in
assert builtins.elem size [
  4
  16
  64
];
(operations.${phase} or (throw "unsupported TOML measurement phase"))
