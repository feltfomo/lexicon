{
  description = "Declarative placement of the generic Praxis package";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, ... }@inputs:
    {
      # the machine configuration you already build; praxis joins its package list
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # the module below reads inputs, so the evaluation has to supply them
        specialArgs = { inherit inputs; };
        modules = [
          (
            { inputs, pkgs, ... }:
            {
              environment.systemPackages = [ inputs.lexicon.packages.${pkgs.system}.praxis ];
              networking.hostName = "workstation";
              system.stateVersion = "26.05";
            }
          )
        ];
      };
    };
}
