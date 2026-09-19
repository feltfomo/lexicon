{
  inputs.lexicon.url = "github:feltfomo/lexicon";
  inputs.nixpkgs.follows = "lexicon/nixpkgs";

  outputs =
    { lexicon, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      ownerships = lexicon.lib.ownerships { };
      roster = ownerships.toRoster [
        (ownerships.define.host "laptop")
        (ownerships.define.user "alice" { hosts = [ "laptop" ]; })
      ];
      # directory names split home and system units while args bind file parameters
      sets = ownerships.importUnitSets {
        dir = ./units;
        args.editor = "helix";
      };
      home = ownerships.mkResolve roster sets.home {
        host.name = "laptop";
        user.name = "alice";
      };
      system = ownerships.mkResolveSystem roster sets.system { host.name = "laptop"; };
      # module evaluation proves resolved values retain normal option priorities
      module = lib.evalModules {
        modules = [
          {
            options.home.sessionVariables = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            config.home.sessionVariables.EDITOR = lib.mkDefault "vim";
          }
          { config = home; }
        ];
      };
    in
    {
      lib = {
        inherit
          roster
          sets
          home
          system
          ;
        moduleEditor = module.config.home.sessionVariables.EDITOR;
      };
    };
}
