{
  description = "Project-local availability of the generic Praxis command";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      status = "ready";

      # the same generic package, reachable only while this shell is entered
      devShells.${system}.default = pkgs.mkShell {
        packages = [ lexicon.packages.${system}.praxis ];
      };

      praxis =
        { pkgs, root, ... }:
        {
          atRoot = true;
          commands.inspect = [
            "nix"
            "eval"
            "--json"
            ".#status"
          ];
        };
    };
}
