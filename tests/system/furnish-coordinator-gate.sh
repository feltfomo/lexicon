#!/usr/bin/env bash
set -euo pipefail

log() { printf '[lexicon-furnish-gate] %s\n' "$*"; }
die() { printf '[lexicon-furnish-gate] ERROR: %s\n' "$*" >&2; exit 1; }

repo="$(git rev-parse --show-toplevel)"
[ "$PWD" = "$repo" ] || cd "$repo"
[ -z "$(git status --porcelain=v1)" ] || die "the gate requires a committed clean Lexicon tree"
rev="$(git rev-parse HEAD)"

log 'running pure and boundary checks'
nix flake check -L

log 'building the native and fault-injection coordinators'
nix build --no-link -L .#furnish-coordinator .#furnish-coordinator-fault-injection

log 'running Go state-machine tests'
(
  cd tests/system/harness
  go test ./...
)

log "provisioning the synthetic Furnish VM at $rev"
nix run .#rebuild-vm-golden -- --rev "$rev" all

log 'running the fail-closed lifecycle proof'
nix run .#program-files-regression -- vm run --flake "$repo"

log 'complete'
