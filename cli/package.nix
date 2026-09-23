# the lexicon binary, which formats, checks, and runs declared commands
#
# the tools are baked into the wrapper rather than looked up on a path,
# because a formatter reading them from the caller's environment would
# produce different bytes for different callers
{
  lib,
  rustPlatform,
  makeWrapper,
  writeText,
  clippy,
  git,
  deadnix,
  nixfmt,
  rustfmt,
  statix,
}:
let
  # the settings the tree's treefmt configuration handed statix, carried over
  # so the same lints are fixed as before
  statixSettings = writeText "statix.toml" ''
    disabled = []
  '';
in
rustPlatform.buildRustPackage {
  pname = "lexicon";

  # read off the manifest cargo builds from, so the two cannot drift
  version = (lib.importTOML ./Cargo.toml).package.version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    clippy
    makeWrapper
  ];

  postCheck = ''
    cargo clippy --offline --locked --all-targets -- -D warnings
  '';

  # git answers which files a tree tracks, so it is a runtime input and not a
  # build one
  postInstall = ''
    wrapProgram $out/bin/lexicon \
      --set LEXICON_DEADNIX ${deadnix}/bin/deadnix \
      --set LEXICON_NIXFMT ${nixfmt}/bin/nixfmt \
      --set LEXICON_RUSTFMT ${rustfmt}/bin/rustfmt \
      --set LEXICON_STATIX ${statix}/bin/statix \
      --set LEXICON_STATIX_CONFIG ${statixSettings} \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  meta = {
    description = "One binary for formatting, checks and declared commands";
    mainProgram = "lexicon";
    platforms = lib.platforms.linux;
  };
}
