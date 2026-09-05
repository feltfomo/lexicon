{ pkgs }:
pkgs.rustPlatform.buildRustPackage {
  pname = "praxis";
  version = "0.2.0";
  src = pkgs.lib.fileset.toSource {
    root = ./runtime;
    fileset = pkgs.lib.fileset.unions [
      ./runtime/Cargo.toml
      ./runtime/Cargo.lock
      ./runtime/src
    ];
  };
  cargoLock.lockFile = ./runtime/Cargo.lock;
  nativeBuildInputs = [ pkgs.clippy ];
  postCheck = ''
    cargo clippy --offline --locked --all-targets -- -D warnings
  '';
  meta = {
    description = "Run commands declared in Nix";
    mainProgram = "praxis";
    platforms = pkgs.lib.platforms.linux;
  };
}
