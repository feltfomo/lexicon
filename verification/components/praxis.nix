{
  project,
  component,
  size,
  bad,
}:
let
  names = builtins.genList (index: "item${toString index}") size;
  pkgs = project.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  result = project.lib.praxis {
    inherit pkgs;
    commands =
      if bad then
        42
      else
        {
          unrelated = throw "praxis workload forced an unrelated command";
          ops =
            builtins.listToAttrs (
              map (name: {
                inherit name;
                value = {
                  command = [ "true" ];
                  parameters.count = {
                    type = "int";
                    default = 7;
                    choices = [
                      7
                      8
                    ];
                  };
                  args = if component == "praxis-diagnostics" then [ 1 ] else [ { param = "count"; } ];
                };
              }) names
            )
            // {
              unused = throw "praxis workload forced an unrelated namespace child";
            };
        };
    tasks.gate = map (name: "ops.${name}") names;
  };
in
if component == "praxis-selected" then
  result.manifests.gate
else
  {
    codes = map (d: d.code) result.diagnostics.gate;
    paths = map (d: d.context.validation.path) result.diagnostics.gate;
    summary = result.diagnosticSummaries.gate;
  }
