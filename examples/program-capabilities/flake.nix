{
  description = "Focused sparse Program capabilities";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    {
      nixpkgs,
      lexicon,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
      program = lexicon.lib.lexicon.forTarget {
        target.host = {
          name = "studio";
          inherit system;
        };
      };
      packageOnly = import ./package.nix { lexicon = program; };
      importsOnly = import ./imports.nix { lexicon = program; };
      nixosOnly = import ./nixos.nix { lexicon = program; };
      empty = program { };
      packageModule =
        (lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [
            packageOnly.homeManager
            { options.home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; }; }
          ];
        }).config;
      importsModule = importsOnly.homeManager { inherit lib pkgs; };
      nixosModule = nixosOnly.nixos {
        inherit lib pkgs;
        config.networking.hostName = "studio";
      };
      hasFurnishRuntime = builtins.any (
        module: builtins.isAttrs module && (module.key or null) == "lexicon/furnish/runtime.nix"
      ) nixosModule.imports;
    in
    {
      lib.results = {
        package = {
          outputs = builtins.attrNames packageOnly;
          package = (builtins.head packageModule.home.packages).pname;
        };
        imports = {
          outputs = builtins.attrNames importsOnly;
          editor = (builtins.head importsModule.imports).home.sessionVariables.EDITOR;
        };
        nixos = {
          outputs = builtins.attrNames nixosOnly;
          normalUser = (builtins.head nixosModule.imports).users.users.river.isNormalUser;
          furnishRuntime = hasFurnishRuntime;
        };
        empty.outputs = builtins.attrNames empty;
      };
    };
}
