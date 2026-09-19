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
      # user is omitted because these declarations never publish home files
      program = lexicon.lib.programDirect {
        target.host = {
          name = "studio";
          inherit system;
        };
      };
      packageOnly = import ./package.nix { inherit program; };
      importsOnly = import ./imports.nix { inherit program; };
      nixosOnly = import ./nixos.nix { inherit program; };
      empty = program { };
      packageModule = packageOnly.homeManager { inherit lib pkgs; };
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
      # these values exist for the documentation tests, not for a real configuration
      lib.results = {
        package = {
          outputs = builtins.attrNames packageOnly;
          package = (builtins.head packageModule.config.content.home.packages).pname;
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
