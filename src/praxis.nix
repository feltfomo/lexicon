args@{
  lib,
  axiom,
  krisis,
  ...
}:
let
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "praxis";
  };
  reporter = krisis.mkReporter { formatDiagnostic = krisis.renderPlain; };
  fields = import ./praxis/fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  surface = import ./praxis/surface.nix { inherit lib fields; };
  spec = reporter.finish (
    surface.project (
      removeAttrs args [
        "lib"
        "axiom"
        "krisis"
        "_prepareOnly"
      ]
    )
  );
  selected = import ./praxis/ownership.nix {
    inherit
      lib
      axiom
      krisis
      fields
      spec
      ;
  };
  normalize = import ./praxis/normalize.nix {
    inherit
      lib
      axiom
      krisis
      problem
      fields
      spec
      ;
  };
  compiled = import ./praxis/compile.nix {
    inherit lib axiom krisis;
    inherit (spec)
      pkgs
      name
      root
      cwd
      requireRoot
      ;
    discoverRoot = if spec.atRoot then "flake.nix" else spec.discoverRoot;
    inherit (spec) ui;
    commands = selected.declarations;
    lower = normalize;
    installWrappers = spec.wrappers;
  };
in
if args._prepareOnly or false then
  compiled.prepared
else
  import ./praxis/outputs.nix {
    inherit
      lib
      fields
      spec
      compiled
      selected
      ;
  }
