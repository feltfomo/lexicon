# praxis projects. manifest demands the whole finite project of size commands.
# selected and diagnostics build a task over size parameterized namespace
# commands beside a throwing command and a throwing namespace sibling, then
# demand the selected manifest or every diagnostic code, path and the summary
{
  api,
  pkgs,
  names,
  records,
  ...
}:
let
  project =
    args:
    api.praxis {
      inherit pkgs;
      commands = {
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
                inherit args;
              };
            }) names
          )
          // {
            unused = throw "praxis workload forced an unrelated namespace child";
          };
      };
      tasks.gate = map (name: "ops.${name}") names;
    };

  # an integer argv entry is invalid, which yields one diagnostic per command
  invalid = project [ 1 ];

  whole = api.praxis {
    inherit pkgs;
    commands = records (_: [ "true" ]);
  };

  # a manifest names the bash it runs under by store path, whose hash moves with
  # nixpkgs, so the projection keeps only the program name
  portable = manifest: manifest // { bash = baseNameOf manifest.bash; };
in
{
  manifest = portable whole.manifest;

  selected = portable (project [ { param = "count"; } ]).manifests.gate;

  diagnostics = {
    codes = map (diagnostic: diagnostic.code) invalid.diagnostics.gate;
    paths = map (diagnostic: diagnostic.context.validation.path) invalid.diagnostics.gate;
    summary = invalid.diagnosticSummaries.gate;
  };
}
