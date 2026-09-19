{
  pkgs,
  genericPraxis,
}:
let
  uniquePackage = pkgs.writeShellScriptBin "praxis-audit-unique-command-20260914" ''
    # realization regression 20260914b
    printf 'unique package ran\n'
  '';
  uniquePath = builtins.unsafeDiscardStringContext (toString uniquePackage);
  closure = pkgs.closureInfo {
    rootPaths = [
      genericPraxis
      pkgs.path
      pkgs.bash
      pkgs.stdenvNoCC
    ];
  };
in
pkgs.runCommandLocal "praxis-installed-consumer"
  {
    nativeBuildInputs = with pkgs; [
      genericPraxis
      coreutils
      gnugrep
      diffutils
      jq
      nix
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export NIX_CONFIG='experimental-features = nix-command flakes pipe-operators'
    mkdir -p "$HOME" "$TMPDIR/empty"

    # outside any project: identity and help work, declarations are unavailable
    cd "$TMPDIR/empty"
    test "$(praxis --version)" = 'praxis 1.0.0'
    praxis help > help
    grep -F "Praxis runs the commands a project's flake.nix exposes as its praxis output." help
    ! praxis list > stdout 2> stderr
    grep -F 'praxis: no project found' stderr

    test_root="$TMPDIR/nix-root"
    unique_path=${uniquePath}
    test_store="local?root=$test_root&state=/tmp/nix-state&log=/tmp/nix-log"
    mkdir -p "$test_root/nix/store" "$test_root/tmp/nix-state" "$test_root/tmp/nix-log"
    while IFS= read -r path; do
      cp -a "$path" "$test_root/nix/store/"
    done < ${closure}/store-paths
    nix-store --store "$test_store" --load-db < ${closure}/registration
    export NIX_REMOTE="$test_store"

    # one declaration text, used unchanged by both file layouts
    cat > "$TMPDIR/declaration.nix" <<'DECLARATION'
    { pkgs, root, ... }:
    {
      name = "configured-name";
      atRoot = true;
      commands = {
        check = [ "nix" "eval" "--raw" ".#value" ];
        choice = [ "${pkgs.coreutils}/bin/printf" "one" ];
        arguments = [ "${pkgs.jq}/bin/jq" "-cn" "--args" "$ARGS.positional" "--" ];
      };
    }
    DECLARATION

    mkdir -p "$TMPDIR/inline/nested" "$TMPDIR/imported/nested"

    {
      printf '{\n'
      printf '  inputs.nixpkgs.url = "path:${pkgs.path}";\n'
      printf '  outputs =\n    { self, nixpkgs }:\n    {\n      value = "configured";\n      praxis =\n'
      cat "$TMPDIR/declaration.nix"
      printf ';\n    };\n}\n'
    } > "$TMPDIR/inline/flake.nix"

    cp "$TMPDIR/declaration.nix" "$TMPDIR/imported/praxis.nix"
    cat > "$TMPDIR/imported/flake.nix" <<'FLAKE'
    {
      inputs.nixpkgs.url = "path:${pkgs.path}";
      outputs =
        { self, nixpkgs }:
        {
          value = "configured";
          praxis = import ./praxis.nix;
        };
    }
    FLAKE

    for layout in inline imported; do
      cd "$TMPDIR/$layout"
      test "$(praxis --version)" = 'praxis 1.0.0'

      praxis list > "$TMPDIR/$layout.list"
      grep -F $'check\t' "$TMPDIR/$layout.list"
      test ! -e flake.lock
      praxis help > project-help
      grep -F 'praxis [RUNNER OPTIONS] NAME' project-help

      # the declared child command keeps nix's ordinary lock behavior
      test "$(praxis --quiet check)" = configured
      test -e flake.lock
      lock_hash=$(sha256sum flake.lock | cut -d' ' -f1)

      # the loader itself never writes the project lock
      praxis list > /dev/null
      test "$(sha256sum flake.lock | cut -d' ' -f1)" = "$lock_hash"

      # only the project directory itself may differ between the two layouts
      normalize() {
        sed "s#$TMPDIR/$layout#PROJECT#g"
      }
      praxis --json plan check | normalize > "$TMPDIR/$layout.plan-check"
      praxis --json plan arguments | normalize > "$TMPDIR/$layout.plan-arguments"
      praxis --json plan choice | normalize > "$TMPDIR/$layout.plan-choice"

      # nested invocation resolves the same nearest project
      cd nested
      test "$(praxis --quiet check)" = configured
      test "$(sha256sum ../flake.lock | cut -d' ' -f1)" = "$lock_hash"
      praxis --quiet arguments 'two words' "" --flag > actual
      jq -e '. == ["two words", "", "--flag"]' actual
      cd ..

      printf '%s\n' "$lock_hash" > "$TMPDIR/$layout.lock-hash"
    done

    # both layouts describe one project identically
    cmp "$TMPDIR/inline.list" "$TMPDIR/imported.list"
    cmp "$TMPDIR/inline.plan-check" "$TMPDIR/imported.plan-check"
    cmp "$TMPDIR/inline.plan-arguments" "$TMPDIR/imported.plan-arguments"
    cmp "$TMPDIR/inline.plan-choice" "$TMPDIR/imported.plan-choice"

    # editing the declaration reevaluates without reinstalling, in either layout
    sed -i 's/"one"/"two"/' "$TMPDIR/inline/flake.nix"
    sed -i 's/"one"/"two"/' "$TMPDIR/imported/praxis.nix"
    for layout in inline imported; do
      cd "$TMPDIR/$layout/nested"
      test "$(praxis --quiet choice)" = two
      test "$(sha256sum ../flake.lock | cut -d' ' -f1)" = "$(cat "$TMPDIR/$layout.lock-hash")"
    done

    # an ordinary invocation realizes the packages its declaration references
    probe_project="$test_root/build/project"
    mkdir -p "$probe_project" "$test_root/tmp/home"
    cd "$probe_project"
    cat > flake.nix <<'FLAKE'
    {
      inputs.nixpkgs.url = "path:${pkgs.path}";
      outputs =
        { self, nixpkgs }:
        {
          praxis =
            { pkgs, root, ... }:
            {
              commands.probe = [
                "''${pkgs.writeShellScriptBin "praxis-audit-unique-command-20260914" "# realization regression 20260914b\nprintf 'unique package ran\\n'\n"}/bin/praxis-audit-unique-command-20260914"
              ];
            };
        };
    }
    FLAKE
    cat > run-praxis.nix <<'RUNNER'
    let
      pkgs = import ${pkgs.path} { };
      praxis = builtins.storePath "${genericPraxis}";
    in
    {
      praxis = pkgs.writeShellScriptBin "praxis-chroot" "exec ''${praxis}/bin/praxis \"$@\"\n";
    }
    RUNNER
    if nix path-info --store "$test_store" "$unique_path" > /dev/null 2>&1; then
      printf 'unique package unexpectedly existed before praxis probe: %s\n' "$unique_path" >&2
      exit 1
    fi
    if ! env HOME=/tmp/home NIX_REMOTE='local?state=/tmp/nix-state&log=/tmp/nix-log' nix run --store "$test_store" --impure --file ./run-praxis.nix praxis -- probe > probe.stdout 2> probe.stderr; then
      cat probe.stderr >&2
      exit 1
    fi
    printf 'unique package ran\n' > probe.expected
    cmp probe.expected probe.stdout
    if ! nix path-info --store "$test_store" "$unique_path" > /dev/null 2>&1; then
      printf 'unique package was not realized before runner execution: %s\n' "$unique_path" >&2
      cat probe.stderr >&2
      exit 1
    fi

    # a flake that does not expose Praxis is reported exactly, without skipping upward
    mkdir -p "$TMPDIR/parent/child"
    cp "$TMPDIR/imported/flake.nix" "$TMPDIR/parent/flake.nix"
    cp "$TMPDIR/imported/praxis.nix" "$TMPDIR/parent/praxis.nix"
    cat > "$TMPDIR/parent/child/flake.nix" <<'FLAKE'
    {
      inputs.nixpkgs.url = "path:${pkgs.path}";
      outputs =
        { self, nixpkgs }:
        {
          value = "unrelated";
        };
    }
    FLAKE
    cd "$TMPDIR/parent/child"
    ! praxis list > stdout 2> stderr
    grep -F "$TMPDIR/parent/child/flake.nix does not expose a praxis output" stderr
    ! grep -F $'choice\t' stdout

    # malformed and invalid declarations fail as project preparation errors
    mkdir "$TMPDIR/broken"
    cd "$TMPDIR/broken"
    printf '{\n' > flake.nix
    ! praxis list > stdout 2> stderr
    grep -F 'praxis: could not prepare' stderr

    cat > flake.nix <<'FLAKE'
    {
      inputs.nixpkgs.url = "path:${pkgs.path}";
      outputs =
        { self, nixpkgs }:
        {
          praxis = { pkgs, root, ... }: { commands.bad = 42; };
        };
    }
    FLAKE
    ! praxis list > stdout 2> stderr
    grep -F 'praxis: could not prepare' stderr

    touch "$out"
  ''
