{
  praxis,
  count ? 2000,
}:
let
  names = builtins.genList (index: "arg${toString index}") count;
  compiled = praxis {
    pkgs = throw "diagnostics forced the package set";
    commands.bench = {
      parameters = map (name: {
        inherit name;
        positional = true;
        required = true;
      }) names;
      steps = [
        {
          exec = [ "true" ] ++ map (param: { inherit param; }) names;
        }
      ];
    };
  };
in
assert compiled.diagnostics.bench == [ ];
count
