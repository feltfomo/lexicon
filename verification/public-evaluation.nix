{ source, system }:
let
  project = builtins.getFlake source;
  pkgs = project.inputs.nixpkgs.legacyPackages.${system};
  inherit (pkgs) lib;
  fx = import project.inputs.krisis.lib.qualifiedNixEffectsSource { inherit lib; };
  native = project.inputs.krisis.lib.krisis { inherit lib fx; };
  report = native.report.run { } (
    native.validation.check {
      type = native.validation.types.Record { value = native.validation.types.Int; };
      code = "qualification/record";
    } { value = 1; }
  );
  declaration =
    project.lib.lexicon.forTarget
      {
        inherit lib;
        target.host = {
          name = "host";
          inherit system;
        };
      }
      {
        homeManager = {
          opaque = throw "native payload forced";
        };
      };
  commands = project.lib.praxis {
    inherit lib pkgs;
    commands = {
      selected = [ "true" ];
      sibling = throw "sibling forced";
    };
  };
in
{
  inherit system;
  sourceKind = builtins.typeOf project.inputs.krisis.lib.qualifiedNixEffectsSource;
  outcome = report.outcome._con;
  checked = (fx.state.forceThunk report.outcome.value)._con;
  outputs = builtins.attrNames declaration;
  manifestVersion = commands.manifests.selected.version;
}
