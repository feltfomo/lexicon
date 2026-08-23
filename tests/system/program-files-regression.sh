#!/usr/bin/env bash

# runtime evidence stays outside the repo; baselines contain only healthy state.
CACHE="${LEXICON_FURNISH_CACHE:-$HOME/.cache/lexicon-furnish-regression}"
FIXTURE_REL=".config/lexicon/static.conf"
FIXTURE_PATH="$HOME/$FIXTURE_REL"
mkdir -p "$CACHE"

log() { printf '[program-files-regression] %s\n' "$*"; }
die() { printf '[program-files-regression] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
program-files-regression <command>

  furnish-symlink --host furnish-vm
  case-prepare --host furnish-vm --mode <absent|dangling|drifted>
  case-switch-assert --host furnish-vm --mode <absent|dangling|drifted>
  case-boot-assert --host furnish-vm --mode <absent|dangling|drifted>
  reboot-prepare --host furnish-vm --mode <absent|dangling|drifted> --run-id <id>
  reboot-assert --host furnish-vm --mode <absent|dangling|drifted> --run-id <id>
  vm provision --flake <path>
  vm run --flake <path>
USAGE
}

require_host() {
  local expected="$1" actual
  actual="$(hostnamectl --static 2>/dev/null || hostname)"
  [ "$actual" = "$expected" ] || die "command is for $expected, running on $actual"
}

system_toplevel() { readlink -f /run/current-system; }
content_hash() { sha256sum -- "$1" | awk '{print $1}'; }

ledger_path() {
  # where applied state lives is a property of the evaluated host, not a
  # constant this harness may assume; asking the configuration keeps the two
  # from drifting apart silently.
  local host
  host="$(hostnamectl --static 2>/dev/null || hostname)"
  nix eval --raw ".#nixosConfigurations.${host}.config.lexicon.furnish.ledgerPath"
}

ledger_field() {
  local ledger="$1" destination="$2" field="$3"
  [ -r "$ledger" ] || return 0
  jq -r --arg destination "$destination" --arg field "$field" \
    '[.records[]|select(.destination==$destination)]|first|.[$field] // empty' "$ledger"
}

home_generation() {
  # integrated home manager has used both profile locations across generations.
  local candidate
  for candidate in "$HOME/.local/state/nix/profiles/home-manager" "$HOME/.nix-profile"; do
    if [ -e "$candidate" ] || [ -L "$candidate" ]; then
      readlink -f "$candidate"
      return
    fi
  done
  printf 'null\n'
}

home_persistence() {
  # a boot result means something different when .config lives on the rolled-back root.
  local mount
  mount="$(findmnt -T "$HOME/.config" -n -o SOURCE,FSROOT,TARGET 2>/dev/null || true)"
  if grep -Eq '(@persist|@home|/persist)' <<<"$mount"; then
    printf 'persisted\n'
  else
    printf 'ephemeral-root\n'
  fi
}

matrix_path() { printf '%s/repair-matrix.json\n' "$CACHE"; }

# fault injection. the points are named after the durability boundaries the
# coordinator actually has, and the crash is a real process death at that point
# rather than an error return, so recovery is exercised the way a power loss
# would exercise it. evidence lands beside the repair matrix in its own file;
# the matrix schema is not touched.
FAULT_POINTS="pre-pending pending-committed stage-written stage-synced published published-synced verified exchange-published"

fault_root() { printf '%s/fault\n' "$CACHE"; }
fault_recovery_path() { printf '%s/furnish-fault-recovery.json\n' "$CACHE"; }

fault_known_point() {
  local point="$1" candidate
  for candidate in $FAULT_POINTS; do
    [ "$candidate" = "$point" ] && return 0
  done
  return 1
}

fault_manifest_json() {
  local destination="$1" root="$2" source="$3" representation="$4" executor="$5" strategy="$6"
  jq -n --arg destination "$destination" --arg root "$root" --arg source "$source" \
    --arg representation "$representation" --arg executor "$executor" --arg strategy "$strategy" '{
    schemaVersion:2,
    diagnosticContract:{
      schemaVersion:1,
      codes:{
        invalidManifest:"runtime/invalid-manifest",
        unsupportedExecutor:"runtime/unsupported-executor",
        invalidDestination:"runtime/invalid-destination",
        parentTraversal:"runtime/parent-traversal",
        conflictingDestination:"runtime/conflicting-destination",
        executorFailed:"runtime/executor-failed",
        stagingVerification:"runtime/staging-verification",
        publishRace:"runtime/publish-race",
        finalVerification:"runtime/final-verification",
        ledgerUnreadable:"runtime/ledger-unreadable",
        ledgerInvalid:"runtime/ledger-invalid",
        ledgerWriteFailed:"runtime/ledger-write-failed",
        repairVerification:"runtime/repair-verification",
        unresolvableDesiredTarget:"runtime/unresolvable-desired-target",
        contentVerification:"runtime/content-verification",
        transitionRefused:"runtime/transition-refused",
        unresolvedRetirement:"runtime/unresolved-retirement",
        pendingRecovery:"runtime/pending-recovery"
      }
    },
    entries:[{
      schemaVersion:2,
      filesystemIdentity:{namespace:"fault",destination:$destination,canonical:("fault:"+$destination)},
      authority:{scope:"system",identity:"fault/system"},
      managedRoot:$root,
      onConflict:"error",
      representation:$representation,
      retainedArtifactTarget:$source,
      executor:{identity:$executor,protocolVersion:1},
      cleanupStrategy:$strategy,
      selfHealStrategy:$strategy,
      provenance:{declaration:"fault-injection",source:"tests/program-files-regression.sh"}
    }]
  }'
}

# scratch only, and under the cache. no host declaration is added and nothing
# outside $CACHE is written.
fault_scratch() {
  local point="$1" scratch
  scratch="$(fault_root)/$point"
  rm -rf "$scratch"
  mkdir -p "$scratch/managed" "$scratch/state" "$scratch/lock"
  printf 'furnish writable payload\n' > "$scratch/source"
  printf '%s\n' "$scratch"
}

fault_run() {
  local coordinator="$1" scratch="$2" manifest="$3" point="$4"
  local setpriv
  setpriv="$(command -v setpriv)" || die "setpriv is required"
  if [ -n "$point" ]; then
    env FURNISH_FAULT_POINT="$point" "$coordinator" reconcile \
      --manifest "$manifest" --lock-name fault.lock --setpriv "$setpriv" \
      --state-dir "$scratch/state" --lock-dir "$scratch/lock"
  else
    "$coordinator" reconcile \
      --manifest "$manifest" --lock-name fault.lock --setpriv "$setpriv" \
      --state-dir "$scratch/state" --lock-dir "$scratch/lock"
  fi
}

fault_prepare() {
  local host="$1" point="$2" coordinator="$3" scratch manifest status
  require_host "$host"
  fault_known_point "$point" || die "unknown fault point: $point"
  [ -x "$coordinator" ] || die "fault coordinator is not executable: $coordinator"
  scratch="$(fault_scratch "$point")"
  manifest="$scratch/manifest.json"

  if [ "$point" = exchange-published ]; then
    # a crash between the exchange and the ledger advancing only happens during a
    # transfer, so an owned symlink has to be established first and then asked to
    # become writable.
    fault_manifest_json "$scratch/managed/value" "$scratch/managed" "$scratch/source" \
      symlink furnish/native-symlink exact-symlink-target > "$manifest"
    fault_run "$coordinator" "$scratch" "$manifest" "" || die "could not establish the owned symlink"
  fi

  fault_manifest_json "$scratch/managed/value" "$scratch/managed" "$scratch/source" \
    writable furnish/native-writable exact-source-content > "$manifest"

  # packaged as a shell application the script runs under errexit; invoked
  # directly with bash it does not. the status is captured explicitly rather
  # than toggled around because that form is correct under both, and a stray
  # set -e or set +e here would change how every other subcommand behaves.
  status=0
  fault_run "$coordinator" "$scratch" "$manifest" "$point" || status=$?
  # abort() is SIGABRT, so a shell reports 134. anything else means the process
  # returned instead of dying, and the point would not be proving what it claims.
  [ "$status" -eq 134 ] || die "fault point $point did not die: exit $status"
  log "fault point $point crashed as expected"
}

fault_assert() {
  local host="$1" point="$2" coordinator="$3" scratch manifest status
  local destination expected actual state baseline recovered entry
  require_host "$host"
  fault_known_point "$point" || die "unknown fault point: $point"
  scratch="$(fault_root)/$point"
  manifest="$scratch/manifest.json"
  [ -f "$manifest" ] || die "no prepared fault scratch for $point"
  destination="$scratch/managed/value"

  status=0
  fault_run "$coordinator" "$scratch" "$manifest" "" || status=$?
  [ "$status" -eq 0 ] || die "recovery run failed at $point: exit $status"

  expected="$(content_hash "$scratch/source")"
  [ -f "$destination" ] || die "recovery at $point left no destination"
  [ -L "$destination" ] && die "recovery at $point left a symlink, not a writable file"
  actual="$(content_hash "$destination")"
  [ "$actual" = "$expected" ] || die "recovery at $point did not converge byte-exactly"

  entry="$(jq -r --arg key "fault:$destination" '.records[$key] // empty' "$scratch/state/applied-state.json")"
  [ -n "$entry" ] || die "recovery at $point recorded no ownership"
  state="$(printf '%s' "$entry" | jq -r '.state')"
  # the ledger serializes camelCase, so the key here must match the file on
  # disk rather than the rust field name.
  baseline="$(printf '%s' "$entry" | jq -r '.baselineHash // empty')"
  [ "$state" = owned ] || die "recovery at $point left state $state"
  [ "$baseline" = "$expected" ] || die "recovery at $point left a stale baseline"

  # no partial write is ever claimed as complete. ownership is asserted here
  # only because the bytes were re-read and re-hashed after the fact.
  recovered="$(jq -n --arg point "$point" --arg hash "$actual" --arg baseline "$baseline" \
    '{point:$point,status:"pass",converged:true,contentHash:$hash,baselineHash:$baseline,ownershipState:"owned"}')"
  if [ -f "$(fault_recovery_path)" ]; then
    jq --argjson entry "$recovered" '.points |= (map(select(.point != $entry.point)) + [$entry])' \
      "$(fault_recovery_path)" > "$(fault_recovery_path).tmp"
  else
    jq -n --argjson entry "$recovered" '{schemaVersion:1,points:[$entry]}' > "$(fault_recovery_path).tmp"
  fi
  mv "$(fault_recovery_path).tmp" "$(fault_recovery_path)"
  log "fault point $point recovered to exact known state"
}

# only b, s, and d all distinct reaches the policy branch. a one-sided change
# could preserve the destination through the ordinary no-op path instead.
runtime_wins_proof() {
  local host="$1" coordinator="$2" scratch manifest destination ledger key
  local baseline_hash source_hash runtime_hash destination_after baseline_after
  local generation_before generation_after
  require_host "$host"
  [ -x "$coordinator" ] || die "runtime-wins coordinator is not executable: $coordinator"
  scratch="$(fault_scratch runtime-wins)"
  manifest="$scratch/manifest.json"
  destination="$scratch/managed/value"
  ledger="$scratch/state/applied-state.json"
  key="fault:$destination"

  printf 'baseline payload\n' > "$scratch/source"
  fault_manifest_json "$destination" "$scratch/managed" "$scratch/source" \
    writable furnish/native-writable exact-source-content \
    | jq '.entries[0].onConflict = "runtime-wins"' > "$manifest"
  fault_run "$coordinator" "$scratch" "$manifest" "" \
    || die "runtime-wins proof could not establish the baseline"
  baseline_hash="$(content_hash "$scratch/source")"
  [ "$(content_hash "$destination")" = "$baseline_hash" ] \
    || die "runtime-wins proof did not establish matching baseline bytes"
  [ "$(jq -r --arg key "$key" '.records[$key].baselineHash // empty' "$ledger")" = "$baseline_hash" ] \
    || die "runtime-wins proof did not record the initial baseline"
  generation_before="$(jq -r --arg key "$key" '.records[$key].appliedOperationGeneration' "$ledger")"

  printf 'new declared payload\n' > "$scratch/source"
  printf 'runtime edited payload\n' > "$destination"
  source_hash="$(content_hash "$scratch/source")"
  runtime_hash="$(content_hash "$destination")"
  [ "$source_hash" != "$baseline_hash" ] && [ "$runtime_hash" != "$baseline_hash" ] \
    && [ "$runtime_hash" != "$source_hash" ] \
    || die "runtime-wins proof did not form the three-way conflict"
  fault_run "$coordinator" "$scratch" "$manifest" "" \
    || die "runtime-wins proof reconcile failed"

  destination_after="$(content_hash "$destination")"
  baseline_after="$(jq -r --arg key "$key" '.records[$key].baselineHash // empty' "$ledger")"
  generation_after="$(jq -r --arg key "$key" '.records[$key].appliedOperationGeneration' "$ledger")"
  [ "$destination_after" = "$runtime_hash" ] \
    || die "runtime-wins proof overwrote the runtime edit"
  [ "$baseline_after" = "$source_hash" ] \
    || die "runtime-wins proof did not settle at the refused source baseline"
  [ "$generation_after" = "$generation_before" ] \
    || die "runtime-wins proof recorded a publication that did not occur"

  jq -n --arg host "$host" --arg baselineBefore "$baseline_hash" \
    --arg sourceBefore "$source_hash" --arg destinationBefore "$runtime_hash" \
    --arg destinationAfter "$destination_after" --arg baselineAfter "$baseline_after" \
    --argjson generationBefore "$generation_before" --argjson generationAfter "$generation_after" \
    '{schemaVersion:1,status:"pass",host:$host,before:{baseline:$baselineBefore,source:$sourceBefore,destination:$destinationBefore},after:{baseline:$baselineAfter,destination:$destinationAfter},runtimeEditPreserved:($destinationAfter==$destinationBefore),baselineAdvancedToSource:($baselineAfter==$sourceBefore),publicationGenerationUnchanged:($generationAfter==$generationBefore)}' \
    > "$CACHE/furnish-runtime-wins-${host}.json"
  log "runtime-wins preserved the runtime edit and settled the source baseline"
}

ensure_matrix() {
  # null cells make an interrupted matrix obvious instead of looking like a pass.
  local matrix
  matrix="$(matrix_path)"
  if [ ! -f "$matrix" ]; then
    jq -n '{absent:{"no-op-switch":null,reboot:null},dangling:{"no-op-switch":null,reboot:null},drifted:{"no-op-switch":null,reboot:null}}' > "$matrix"
  fi
}

record_matrix() {
  local mode="$1" column="$2" outcome="$3" matrix tmp
  ensure_matrix
  matrix="$(matrix_path)"
  tmp="${matrix}.tmp"
  jq --arg mode "$mode" --arg column "$column" --arg outcome "$outcome" '.[$mode][$column]=$outcome' "$matrix" > "$tmp"
  mv "$tmp" "$matrix"
}

save_case_state() {
  local mode="$1" file="$2" raw resolved hash ledger ledger_schema applied
  [ -L "$FIXTURE_PATH" ] || die "$FIXTURE_PATH is not a healthy owned symlink"
  raw="$(readlink -- "$FIXTURE_PATH")"
  resolved="$(readlink -f -- "$FIXTURE_PATH")"
  [ -e "$resolved" ] || die "$FIXTURE_PATH is already dangling"
  hash="$(content_hash "$FIXTURE_PATH")"
  # the before side of the ledger comparison is captured here so both halves of
  # the reboot assertion come from one place rather than being reconstructed
  # after the wipe from something that may itself have changed.
  ledger="$(ledger_path)"
  ledger_schema="$(jq -r .schemaVersion "$ledger" 2>/dev/null || true)"
  applied="$(ledger_field "$ledger" "$FIXTURE_PATH" appliedArtifactTarget)"
  jq -n --arg mode "$mode" --arg path "$FIXTURE_PATH" --arg rawTarget "$raw" --arg resolvedTarget "$resolved" --arg contentSha256 "$hash" --arg systemToplevel "$(system_toplevel)" --arg bootId "$(cat /proc/sys/kernel/random/boot_id)" --arg homePersistence "$(home_persistence)" --arg ledgerPath "$ledger" --arg ledgerSchemaVersion "$ledger_schema" --arg ledgerAppliedTarget "$applied" '{mode:$mode,path:$path,rawTarget:$rawTarget,resolvedTarget:$resolvedTarget,contentSha256:$contentSha256,systemToplevel:$systemToplevel,bootId:$bootId,homePersistence:$homePersistence,ledgerPath:$ledgerPath,ledgerSchemaVersion:(if $ledgerSchemaVersion=="" then null else ($ledgerSchemaVersion|tonumber) end),ledgerAppliedTarget:(if $ledgerAppliedTarget=="" then null else $ledgerAppliedTarget end)}' > "$file"
}

restore_fixture() {
  local state="$1" raw expected_hash
  raw="$(jq -r .rawTarget "$state")"
  expected_hash="$(jq -r .contentSha256 "$state")"
  rm -f -- "$FIXTURE_PATH"
  ln -s -- "$raw" "$FIXTURE_PATH"
  [ "$(content_hash "$FIXTURE_PATH")" = "$expected_hash" ] || die "fixture restoration hash mismatch"
}

case_prepare() {
  # the three states expose the backend's missing-versus-invalid-presence behavior.
  local host="$1" mode="$2" state fixture manufactured
  require_host "$host"
  case "$mode" in absent|dangling|drifted) ;; *) die "unknown repair-matrix mode: $mode";; esac
  state="$CACHE/case-${mode}-state.json"
  save_case_state "$mode" "$state"
  case "$mode" in
    absent)
      rm -- "$FIXTURE_PATH"
      ;;
    dangling)
      # delete a real store object first; a made-up path wouldn't prove GC-shaped drift.
      fixture="$CACHE/dangling-fixture"
      printf 'removed fixture target fixture\n' > "$fixture"
      manufactured="$(nix store add-file "$fixture")"
      nix-store --delete "$manufactured" >/dev/null
      [ ! -e "$manufactured" ] || die "could not remove dangling fixture target"
      ln -sfn -- "$manufactured" "$FIXTURE_PATH"
      ;;
    drifted)
      # keep this object live so the drifted case can't collapse into the dangling case.
      fixture="$CACHE/drifted-fixture"
      printf 'wrong fixture content fixture\n' > "$fixture"
      manufactured="$(nix store add-file "$fixture")"
      [ -e "$manufactured" ] || die "could not create drifted fixture target"
      [ "$(content_hash "$manufactured")" != "$(jq -r .contentSha256 "$state")" ] || die "drifted fixture unexpectedly matches desired content"
      ln -sfn -- "$manufactured" "$FIXTURE_PATH"
      ;;
  esac
  jq --arg manufacturedTarget "$(readlink -- "$FIXTURE_PATH" 2>/dev/null || true)" '. + {manufacturedTarget:$manufacturedTarget}' "$state" > "${state}.tmp"
  mv "${state}.tmp" "$state"
  log "prepared $mode fixture state at boot ID $(jq -r .bootId "$state")"
}

case_outcome() {
  # repair requires both the expected target identity and its exact bytes.
  local state="$1" expected_target expected_hash
  expected_target="$(jq -r .resolvedTarget "$state")"
  expected_hash="$(jq -r .contentSha256 "$state")"
  if [ -L "$FIXTURE_PATH" ] && [ "$(readlink -f -- "$FIXTURE_PATH" || true)" = "$expected_target" ] && [ "$(content_hash "$FIXTURE_PATH" 2>/dev/null || true)" = "$expected_hash" ]; then
    printf 'repaired\n'
  else
    printf 'not-repaired\n'
  fi
}

case_switch_assert() {
  local host="$1" mode="$2" state before after outcome manufactured
  require_host "$host"
  state="$CACHE/case-${mode}-state.json"
  [ -f "$state" ] || die "case state is missing for $mode"
  before="$(jq -r .systemToplevel "$state")"
  after="$(system_toplevel)"
  [ "$before" = "$after" ] || die "switch changed the toplevel: $before -> $after"
  outcome="$(case_outcome "$state")"
  manufactured="$(jq -r .manufacturedTarget "$state")"
  if [ "$mode" = absent ]; then
    [ "$outcome" = repaired ] || die "absent static.conf was not repaired"
  else
    [ "$outcome" = not-repaired ] || die "$mode static.conf was unexpectedly repaired"
    [ -L "$FIXTURE_PATH" ] && [ "$(readlink -- "$FIXTURE_PATH")" = "$manufactured" ] || die "$mode fixture changed instead of remaining invalid"
  fi
  record_matrix "$mode" "no-op-switch" "$outcome"
  jq -n --arg mode "$mode" --arg before "$before" --arg after "$after" --arg outcome "$outcome" --arg manufacturedTarget "$manufactured" '{mode:$mode,systemToplevelBefore:$before,systemToplevelAfter:$after,byteIdenticalToplevel:($before==$after),outcome:$outcome,manufacturedTarget:$manufacturedTarget}' > "$CACHE/case-${mode}-switch-evidence.json"
  if [ "$outcome" != repaired ]; then restore_fixture "$state"; fi
  [ "$(case_outcome "$state")" = repaired ] || die "failed to restore healthy static.conf"
  log "$mode no-op switch outcome: $outcome; healthy state verified"
}

case_boot_assert() {
  # a changed boot ID prevents a second shell invocation from masquerading as reboot proof.
  local host="$1" mode="$2" state before after outcome manufactured fixture_valid expected_hash
  local ledger ledger_schema applied_before applied_after applied_by record_boot_id ledger_boot_id_changed
  require_host "$host"
  state="$CACHE/case-${mode}-state.json"
  [ -f "$state" ] || die "case state is missing for $mode"
  before="$(jq -r .bootId "$state")"
  after="$(cat /proc/sys/kernel/random/boot_id)"
  [ "$before" != "$after" ] || die "boot ID did not change"
  outcome="$(case_outcome "$state")"

  # the ledger is the whole claim here. /persist outlives the initrd snapshot that
  # rolls @ back to @blank, and without the record furnish can prove ownership of
  # nothing once the root is gone. record identity is asserted, never file bytes,
  # because the boot reconcile legitimately rewrites this file and a byte-identical
  # ledger across a boot would mean the boot service never ran.
  ledger="$(jq -r .ledgerPath "$state")"
  [ -f "$ledger" ] || die "applied-state ledger did not survive the reboot: $ledger"
  ledger_schema="$(jq -r .schemaVersion "$ledger")"
  [ "$ledger_schema" = "$(jq -r .ledgerSchemaVersion "$state")" ] || die "applied-state schema changed across the reboot"
  applied_before="$(jq -r .ledgerAppliedTarget "$state")"
  applied_after="$(ledger_field "$ledger" "$FIXTURE_PATH" appliedArtifactTarget)"
  applied_by="$(ledger_field "$ledger" "$FIXTURE_PATH" appliedBy)"
  [ -n "$applied_after" ] || die "applied state lost its record for $FIXTURE_PATH"
  [ -n "$applied_by" ] || die "applied state does not say which branch published $FIXTURE_PATH"
  if [ "$applied_before" != null ]; then
    [ "$applied_after" = "$applied_before" ] || die "recorded target changed across the reboot: $applied_before -> $applied_after"
  fi
  record_boot_id="$(ledger_field "$ledger" "$FIXTURE_PATH" bootId)"
  ledger_boot_id_changed=false
  if [ -n "$record_boot_id" ] && [ "$record_boot_id" != "$before" ]; then ledger_boot_id_changed=true; fi
  # only a reconcile that published something rewrites the record, so a refused
  # mode legitimately still carries the previous boot's diagnostic ID.
  if [ "$outcome" = repaired ]; then
    [ "$ledger_boot_id_changed" = true ] || die "ledger boot ID did not advance despite a repaired outcome"
  fi

  record_matrix "$mode" reboot "$outcome"
  if [ "$host" = furnish-vm ]; then
    manufactured="$(jq -r .manufacturedTarget "$state")"
    expected_hash="$(jq -r .contentSha256 "$state")"
    fixture_valid=true
    case "$mode" in
      absent) [ "$outcome" = repaired ] || fixture_valid=false ;;
      dangling) [ -L "$FIXTURE_PATH" ] && [ "$(readlink -- "$FIXTURE_PATH")" = "$manufactured" ] && [ ! -e "$manufactured" ] || fixture_valid=false ;;
      drifted) [ -L "$FIXTURE_PATH" ] && [ "$(readlink -- "$FIXTURE_PATH")" = "$manufactured" ] && [ -e "$manufactured" ] && [ "$(content_hash "$manufactured")" != "$expected_hash" ] || fixture_valid=false ;;
    esac
    [ "$fixture_valid" = true ] || die "$mode fixture changed shape across reboot"
  fi
  if [ "$outcome" != repaired ]; then restore_fixture "$state"; fi
  [ "$(case_outcome "$state")" = repaired ] || die "failed to restore healthy static.conf"
  if [ "$host" = furnish-vm ]; then
    jq -n --arg mode "$mode" --arg bootIdBefore "$before" --arg bootIdAfter "$after" --arg outcome "$outcome" \
      --arg homePersistence "$(jq -r .homePersistence "$state")" --arg manufacturedTarget "$manufactured" \
      --argjson fixtureStateValid "$fixture_valid" \
      --arg ledgerPath "$ledger" --arg ledgerAppliedTarget "$applied_after" --arg ledgerAppliedBy "$applied_by" \
      --argjson ledgerBootIdChanged "$ledger_boot_id_changed" \
      '{mode:$mode,bootIdBefore:$bootIdBefore,bootIdAfter:$bootIdAfter,bootIdChanged:($bootIdBefore!=$bootIdAfter),outcome:$outcome,homePersistence:$homePersistence,manufacturedTarget:$manufacturedTarget,fixtureStateValid:$fixtureStateValid,ledgerPath:$ledgerPath,ledgerAppliedTarget:$ledgerAppliedTarget,ledgerAppliedBy:$ledgerAppliedBy,ledgerBootIdChanged:$ledgerBootIdChanged,ledgerSurvived:true,ledgerRecordStable:true,healthyStateRestored:true}' \
      > "$CACHE/case-${mode}-boot-evidence.json"
  else
    jq -n --arg mode "$mode" --arg bootIdBefore "$before" --arg bootIdAfter "$after" --arg outcome "$outcome" --arg homePersistence "$(jq -r .homePersistence "$state")" --arg ledgerPath "$ledger" --arg ledgerAppliedTarget "$applied_after" --arg ledgerAppliedBy "$applied_by" --argjson ledgerBootIdChanged "$ledger_boot_id_changed" '{mode:$mode,bootIdBefore:$bootIdBefore,bootIdAfter:$bootIdAfter,bootIdChanged:($bootIdBefore!=$bootIdAfter),outcome:$outcome,homePersistence:$homePersistence,ledgerPath:$ledgerPath,ledgerAppliedTarget:$ledgerAppliedTarget,ledgerAppliedBy:$ledgerAppliedBy,ledgerBootIdChanged:$ledgerBootIdChanged,ledgerSurvived:true,ledgerRecordStable:true,healthyStateRestored:true}' > "$CACHE/case-${mode}-boot-evidence.json"
  fi
  log "$mode reboot outcome: $outcome; healthy state verified"
}

roots_check() {
  # a live target isn't retention evidence until an active root reaches it.
  local host="$1" target roots
  require_host "$host"
  [ -L "$FIXTURE_PATH" ] || die "static.conf is not a symlink"
  target="$(readlink -f -- "$FIXTURE_PATH")"
  roots="$(nix-store -q --roots "$target" 2>/dev/null || true)"
  [ -n "$roots" ] || die "no GC root reaches $target"
  printf '%s\n' "$roots" > "$CACHE/${host}-fixture-roots.txt"
  log "active roots retain $target"
}

furnish_symlink() {
  local host="$1" manifest target raw
  require_host "$host"
  manifest="$(nix eval --json ".#nixosConfigurations.${host}.config.lexicon.furnish.manifestData")"
  [ "$(jq '[.[]|select(.filesystemIdentity.destination=="/home/tester/.config/lexicon/static.conf")]|length' <<<"$manifest")" -eq 1 ]     || die "furnish manifest does not contain exactly one static.conf entry"
  target="$(jq -r '.[]|select(.filesystemIdentity.destination=="/home/tester/.config/lexicon/static.conf")|.retainedArtifactTarget' <<<"$manifest")"
  [ -L "$FIXTURE_PATH" ] || die "static.conf is not a symlink"
  raw="$(readlink -- "$FIXTURE_PATH")"
  [ "$raw" = "$target" ] || die "static.conf does not point at the exact retained target"
  [ -e "$target" ] || die "retained fixture target is missing"
  jq -n --arg host "$host" --arg destination "$FIXTURE_PATH" --arg target "$target" --arg rawTarget "$raw"     '{schemaVersion:1,status:"pass",host:$host,destination:$destination,representation:"symlink",exactTarget:($target==$rawTarget),targetExists:true,statelessSemantics:true}'     > "$CACHE/furnish-symlink-${host}.json"
  log "furnish native symlink target is exact for $host"
}

expected_matrix() {
  jq -n '{absent:{"no-op-switch":"repaired",reboot:"repaired"},dangling:{"no-op-switch":"not-repaired",reboot:"not-repaired"},drifted:{"no-op-switch":"not-repaired",reboot:"not-repaired"}}'
}

normalize_matrix() {
  jq -S '{absent:{"no-op-switch":.absent["no-op-switch"],reboot:.absent.reboot},dangling:{"no-op-switch":.dangling["no-op-switch"],reboot:.dangling.reboot},drifted:{"no-op-switch":.drifted["no-op-switch"],reboot:.drifted.reboot}}' "$1"
}

reboot_prepare() {
  local host="$1" mode="$2" run_id="$3" sentinel state
  sentinel="$CACHE/vm-run-sentinel"
  state="$CACHE/case-${mode}-persistence-state.json"
  require_host "$host"
  if [ ! -f "$sentinel" ]; then printf '%s\n' "$run_id" > "$sentinel"; fi
  [ "$(cat "$sentinel")" = "$run_id" ] || die "persisted run sentinel changed"
  printf '%s\n' "$run_id:$mode" > "/root/program-files-regression-${mode}-root-marker"
  find "$CACHE" -maxdepth 1 -type f -name '*.json' ! -name 'case-*-persistence-state.json' -print0 \
    | sort -z | xargs -0 sha256sum > "$CACHE/case-${mode}-persisted-files.sha256"
  jq -n --arg runId "$run_id" --arg mode "$mode" --arg sentinelHash "$(content_hash "$sentinel")" \
    --arg evidenceSetHash "$(content_hash "$CACHE/case-${mode}-persisted-files.sha256")" \
    --arg bootId "$(cat /proc/sys/kernel/random/boot_id)" \
    '{runId:$runId,mode:$mode,sentinelHash:$sentinelHash,evidenceSetHash:$evidenceSetHash,bootId:$bootId}' > "$state"
  log "prepared persistence controls for $mode"
}

reboot_assert() {
  local host="$1" mode="$2" run_id="$3" sentinel state
  sentinel="$CACHE/vm-run-sentinel"
  state="$CACHE/case-${mode}-persistence-state.json"
  local marker="/root/program-files-regression-${mode}-root-marker" before after sentinel_hash
  require_host "$host"
  [ -f "$state" ] || die "persistence state is missing for $mode"
  [ -f "$sentinel" ] || die "persisted run sentinel disappeared"
  [ "$(cat "$sentinel")" = "$run_id" ] || die "persisted run sentinel changed"
  [ ! -e "$marker" ] || die "rolled-back root marker survived reboot"
  sentinel_hash="$(content_hash "$sentinel")"
  [ "$sentinel_hash" = "$(jq -r .sentinelHash "$state")" ] || die "persisted run sentinel hash changed"
  [ "$(content_hash "$CACHE/case-${mode}-persisted-files.sha256")" = "$(jq -r .evidenceSetHash "$state")" ] || die "persisted evidence manifest changed"
  sha256sum -c "$CACHE/case-${mode}-persisted-files.sha256" >/dev/null || die "persisted evidence changed or disappeared"
  before="$(jq -r .bootId "$state")"
  after="$(cat /proc/sys/kernel/random/boot_id)"
  [ "$before" != "$after" ] || die "boot ID did not change for persistence control"
  jq -n --arg runId "$run_id" --arg mode "$mode" --arg before "$before" --arg after "$after" \
    --arg sentinelHash "$sentinel_hash" \
    '{runId:$runId,mode:$mode,bootIdBefore:$before,bootIdAfter:$after,bootIdChanged:($before!=$after),persistedSentinelSurvived:true,persistedSentinelUnchanged:true,persistedEvidenceSetSurvived:true,rolledBackRootMarkerVanished:true,negativeControlPassed:true}' \
    > "$CACHE/case-${mode}-persistence-evidence.json"
  log "$mode persistence and rollback controls passed"
}

ssh_vm() {
  ssh -i "$VM_KEY" -p "$VM_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o LogLevel=ERROR -o ConnectTimeout=5 "$VM_USER@localhost" "$@"
}

ssh_root() {
  local command
  printf -v command '%q ' "$@"
  ssh_vm "printf '%s\n' '$VM_SUDO_PASSWORD' | sudo -S -p '' -- $command"
}

scp_from_vm() {
  scp -i "$VM_KEY" -P "$VM_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o LogLevel=ERROR "$@"
}

vm_paths() {
  VM_CACHE="${LEXICON_FURNISH_VM_CACHE:-$HOME/.cache/lexicon-furnish-vm}"
  VM_KEY="${LEXICON_FURNISH_VM_KEY:-$VM_CACHE/program-files-base-key}"
  VM_USER="${LEXICON_FURNISH_VM_USER:-tester}"
  VM_SUDO_PASSWORD="${LEXICON_FURNISH_VM_SUDO_PASSWORD:-unused}"
  VM_PORT="${LEXICON_FURNISH_VM_PORT:-2222}"
  VM_BASE="$VM_CACHE/program-files-base.qcow2"
  VM_BASE_VARS="$VM_CACHE/program-files-base-vars.fd"
  VM_PROVISION="$VM_CACHE/program-files-base.json"
}

vm_require_common() {
  command -v nix >/dev/null || die "nix is required"
  [ -n "${OVMF_FD:-}" ] || die "OVMF_FD is missing"
  vm_paths
  mkdir -p "$VM_CACHE"
}

vm_require_run() {
  vm_require_common
  [ -f "$VM_KEY" ] || die "missing installed-VM key at $VM_KEY"
  chmod 600 "$VM_KEY" 2>/dev/null || true
}

vm_provision() {
  # the go harness owns identity generation, signed cache setup and freezing.
  local flake="$1" rev status
  command -v git >/dev/null || die "git is required"
  rev="$(git -C "$flake" rev-parse --verify HEAD)"
  status="$(git -C "$flake" status --porcelain=v1)"
  [ -z "$status" ] || die "golden provisioning requires a committed clean tree"
  log "provisioning the lifecycle base through rebuild-vm-golden at $rev"
  nix run "${flake}#rebuild-vm-golden" -- --rev "$rev" all
}

vm_wait_ssh() {
  local up=0
  for _ in $(seq 1 60); do
    if ssh_vm true 2>/dev/null; then up=1; break; fi
    kill -0 "$QEMU_PID" 2>/dev/null || die "VM exited before SSH; see $VM_SERIAL"
    sleep 5
  done
  [ "$up" = 1 ] || die "VM did not accept SSH"
}

vm_start() {
  : > "$VM_SERIAL"
  qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 8192 -smp 4 \
    -drive "if=pflash,format=raw,readonly=on,file=$VM_CODE" \
    -drive "if=pflash,format=raw,file=$VM_RUN_VARS" \
    -drive "file=$VM_OVERLAY,if=virtio,format=qcow2" \
    -netdev "user,id=net0,hostfwd=tcp::$VM_PORT-:22" -device virtio-net,netdev=net0 \
    -display none -serial "file:$VM_SERIAL" -no-reboot -boot order=c &
  QEMU_PID=$!
  vm_wait_ssh
}

vm_stop() {
  if [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
    kill "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
  fi
  QEMU_PID=""
}

vm_reboot() {
  ssh_root reboot >/dev/null 2>&1 || true
  wait "$QEMU_PID" 2>/dev/null || true
  QEMU_PID=""
  vm_start
}

vm_guest_harness() {
  # guest subcommands evaluate .#furnish-vm. run them from the exact prepared
  # archive instead of the SSH user's flake-less home directory.
  ssh_vm env --chdir="$VM_ARCHIVE" PWD="$VM_ARCHIVE" \
    HOME=/home/tester LEXICON_FURNISH_CACHE=/home/tester/.cache/lexicon-furnish-regression \
    "$VM_APP/bin/program-files-regression" "$@"
}

vm_guest_harness_root() {
  ssh_root env --chdir="$VM_ARCHIVE" PWD="$VM_ARCHIVE" \
    HOME=/home/tester LEXICON_FURNISH_CACHE=/home/tester/.cache/lexicon-furnish-regression \
    "$VM_APP/bin/program-files-regression" "$@"
}

vm_prepare_test_flake() {
  local flake="$1" destination="$2"
  git -C "$flake" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "VM test source must be a Git worktree: $flake"
  mkdir -p "$destination"
  (
    cd "$flake"
    git ls-files -z | tar --null -T - -cf -
  ) | tar -C "$destination" -xf -

  # every lifecycle generation must keep the transport identity frozen with
  # the base, or activating a newly built toplevel locks the harness out.
  local key_type key_body public_line placeholder fixture
  read -r key_type key_body _ < <(ssh-keygen -y -f "$VM_KEY")
  [ -n "$key_type" ] && [ -n "$key_body" ] || die "could not derive the golden transport public key"
  public_line="$key_type $key_body lexicon-furnish-vm-test"
  placeholder="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElUx+G8NdV6W0NVEh3wpOg33mBnHY0oG9b31eds/LSs furnish-vm-test"
  for fixture in \
    "$destination/tests/system/fixture/host.nix" \
    "$destination/tests/system/fixture/installer.nix"; do
    grep -Fq -- "$placeholder" "$fixture" || die "transport-key placeholder is missing from $fixture"
    sed -i "s|$placeholder|$public_line|g" "$fixture"
  done

  git -C "$destination" init -q
  git -C "$destination" add -A
  git -C "$destination" -c user.name=program-files-regression \
    -c user.email=program-files-regression@invalid commit -qm "disposable Lexicon VM source"
}

vm_copy_closures() {
  # these closures are built after golden provisioning and are not signed by
  # its cache key. copy through the guest's trusted root account rather than
  # asking the untrusted test user to import unsigned store paths.
  local ssh_opts
  ssh_opts="-i $VM_KEY -p $VM_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o LogLevel=ERROR"
  env NIX_SSHOPTS="$ssh_opts" nix copy --no-check-sigs --to "ssh-ng://root@localhost" "$VM_TOPLEVEL" "$VM_APP" "$VM_COORDINATOR" "$VM_FAULT_COORDINATOR" "$VM_ARCHIVE"
  ssh_root mkdir -p /nix/var/nix/gcroots/program-files-regression
  ssh_root ln -sfn "$VM_TOPLEVEL" /nix/var/nix/gcroots/program-files-regression/system
  ssh_root ln -sfn "$VM_APP" /nix/var/nix/gcroots/program-files-regression/harness
  ssh_root ln -sfn "$VM_ARCHIVE" /nix/var/nix/gcroots/program-files-regression/source
}

vm_copy_toplevel() {
  # variant checks need only one rooted system toplevel. root performs the
  # unsigned import for the same trust reason as the initial closure copy.
  local toplevel="$1" ssh_opts
  ssh_opts="-i $VM_KEY -p $VM_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o LogLevel=ERROR"
  env NIX_SSHOPTS="$ssh_opts" nix copy --no-check-sigs --to "ssh-ng://root@localhost" "$toplevel"
  ssh_root mkdir -p /nix/var/nix/gcroots/program-files-regression
  ssh_root ln -sfn "$toplevel" /nix/var/nix/gcroots/program-files-regression/variant-system
}

vm_select_toplevel() {
  # activate and select the native furnish generation directly.
  ssh_root nix-env -p /nix/var/nix/profiles/system --set "$VM_TOPLEVEL"
  ssh_root "$VM_TOPLEVEL/bin/switch-to-configuration" switch
  [ "$(ssh_vm readlink -f /run/current-system)" = "$VM_TOPLEVEL" ] \
    || die "native generation stopped being active before boot selection"
  [ "$(ssh_vm readlink -f /nix/var/nix/profiles/system)" = "$VM_TOPLEVEL" ] \
    || die "native generation was not selected as the boot profile"
  log "native generation selected as the boot default"
}

vm_assert_selected_after_boot() {
  local mode="$1" actual
  ssh_vm mkdir -p /home/tester/.cache/lexicon-furnish-regression
  actual="$(ssh_vm readlink -f /run/current-system)"
  [ "$actual" = "$VM_TOPLEVEL" ] || die "reboot selected $actual instead of $VM_TOPLEVEL"
  ssh_vm test "$(ssh_vm readlink -f /nix/var/nix/profiles/system)" = "$VM_TOPLEVEL"
  ssh_vm test -e /nix/var/nix/gcroots/program-files-regression/system
  ssh_vm test -e /nix/var/nix/gcroots/program-files-regression/harness
  local evidence_name="case-${mode}-generation-evidence.json"
  [ "$mode" != initial ] || evidence_name="initial-generation-evidence.json"
  jq -n --arg mode "$mode" --arg expected "$VM_TOPLEVEL" --arg actual "$actual" \
    '{mode:$mode,expectedToplevel:$expected,actualToplevel:$actual,exactGenerationSelected:($expected==$actual),systemRootPresent:true,harnessRootPresent:true}' \
    | ssh_vm "cat > /home/tester/.cache/lexicon-furnish-regression/$evidence_name"
}

vm_noop_switch() {
  local mode="$1" before after rc switch_log
  before="$(ssh_vm readlink -f /run/current-system)"
  switch_log="$CACHE/case-${mode}-switch-command.log"
  if ssh_root nixos-rebuild switch --flake "$VM_ARCHIVE#furnish-vm" 2>&1 | tee "$switch_log"; then
    rc=0
  else
    rc=${PIPESTATUS[0]}
  fi
  after="$(ssh_vm readlink -f /run/current-system)"
  [ "$before" = "$after" ] || die "no-op switch changed the toplevel: $before -> $after"
  [ "$after" = "$VM_TOPLEVEL" ] || die "no-op switch selected an unexpected toplevel"
  case "$mode" in
    absent)
      [ "$rc" -eq 0 ] || die "absent no-op switch failed (rc=$rc)"
      ;;
    dangling|drifted)
      [ "$rc" -ne 0 ] || die "$mode no-op switch unexpectedly accepted the conflicting destination"
      grep -F '"code":"runtime/conflicting-destination"' "$switch_log" >/dev/null \
        || die "$mode no-op switch failed without the conflicting-destination diagnostic"
      ;;
    *) die "unknown no-op switch mode: $mode";;
  esac
}

vm_gc_survival() {
  local target_before target_after roots_before roots_after
  target_before="$(ssh_vm readlink -f /home/tester/.config/lexicon/static.conf)"
  [ -n "$target_before" ] || die "VM fixture target is missing before GC"
  roots_before="$(ssh_root nix-store -q --roots "$target_before")"
  [ -n "$roots_before" ] || die "VM fixture target has no root before GC"
  ssh_root nix-collect-garbage -d >/dev/null
  ssh_vm test -L /home/tester/.config/lexicon/static.conf
  target_after="$(ssh_vm readlink -f /home/tester/.config/lexicon/static.conf)"
  [ "$target_after" = "$target_before" ] || die "VM fixture target changed across GC"
  ssh_vm test -e "$target_after"
  roots_after="$(ssh_root nix-store -q --roots "$target_after")"
  [ -n "$roots_after" ] || die "VM fixture target lost its root after GC"
  jq -n --arg targetBefore "$target_before" --arg targetAfter "$target_after"     --arg rootsBefore "$roots_before" --arg rootsAfter "$roots_after"     '{schemaVersion:1,status:"pass",targetBefore:$targetBefore,targetAfter:$targetAfter,exactTargetSurvived:($targetBefore==$targetAfter),targetExistsAfterGc:true,rootPresentBefore:true,rootPresentAfter:true,positiveGcRun:true}'     | ssh_vm 'cat > /home/tester/.cache/lexicon-furnish-regression/furnish-gc-survival.json'
}

vm_build_variant_toplevel() {
  # the only honest second target is one a real declaration produced. perturb the
  # declared fixture source the way a user edit would and evaluate the same module,
  # rather than hand-writing a manifest entry the module never emitted.
  local source="$1" destination="$2" config toplevel
  [ ! -e "$destination" ] || die "variant source already exists: $destination"
  cp -a "$source" "$destination"
  config="$destination/tests/system/fixture/payload.conf"
  [ -f "$config" ] || die "variant source is missing the declared fixture payload: $config"
  printf '\n# two-generation gc repair fixture\n' >> "$config"
  git -C "$destination" -c user.name=program-files-regression \
    -c user.email=program-files-regression@invalid commit -qam "gc repair variant source"
  toplevel="$(nix build --no-link --print-out-paths "${destination}#nixosConfigurations.furnish-vm.config.system.build.toplevel")"
  { [[ "$toplevel" == /nix/store/* ]] && [ -e "$toplevel" ]; } \
    || die "variant generation did not produce a live system toplevel: $toplevel"
  printf '%s\n' "$toplevel"
}

vm_ledger_field() {
  ssh_vm cat "$1" | jq -r --arg destination "$2" --arg field "$3" \
    '[.records[]|select(.destination==$destination)]|first|.[$field] // empty'
}

vm_build_disabled_toplevel() {
  # masking writes into /etc, which this guest wipes on every boot, so a masked
  # unit would dissolve at exactly the moment it has to hold. declaring furnish
  # off is inert by construction and nothing in the rollback can undo it.
  local source="$1" flake_ref disabled_expr probe toplevel
  flake_ref="$(printf '%s' "git+file://$source" | jq -Rs .)"
  disabled_expr="let
    flake = builtins.getFlake $flake_ref;
  in
    flake.nixosConfigurations.furnish-vm.extendModules {
      modules = [
        ({ lib, ... }: {
          lexicon.furnish.enable = lib.mkForce false;
        })
      ];
    }"
  probe="$(nix eval --impure --json --expr "let disabled = ($disabled_expr); in {
    enabled = disabled.config.lexicon.furnish.enable;
    hasActivation = disabled.config.system.activationScripts ? furnish;
    hasBootService = disabled.config.systemd.services ? furnish;
  }")"
  jq -e '.enabled == false and .hasActivation == false and .hasBootService == false' <<<"$probe" >/dev/null \
    || die "disabled generation still carries a furnish activation script or unit"
  printf '%s\n' "$probe" | jq -S . > "$CACHE/disabled-generation-probe.json"
  toplevel="$(nix build --impure --no-link --print-out-paths --expr "($disabled_expr).config.system.build.toplevel")"
  { [[ "$toplevel" == /nix/store/* ]] && [ -e "$toplevel" ]; } \
    || die "disabled generation did not produce a live system toplevel: $toplevel"
  printf '%s\n' "$toplevel"
}

vm_gc_repair_survival() {
  # nothing here passes --ignore-liveness, because the artifact has to become
  # unreachable on its own or the reap proves nothing. runs last because it burns
  # a generation and reboots three times.
  local source="$1" destination="$2" guest_path=/home/tester/.config/lexicon/static.conf
  local ledger variant variant_target base_target disabled inert_load_state
  local recorded_before recorded_updated recorded_after branch_updated branch_after
  local linked_before linked_updated linked_intermediate linked_after
  local update_result repair_result
  ledger="$(nix eval --raw "${source}#nixosConfigurations.furnish-vm.config.lexicon.furnish.ledgerPath")"
  linked_before="$(ssh_vm readlink -- "$guest_path")"
  recorded_before="$(vm_ledger_field "$ledger" "$guest_path" appliedArtifactTarget)"
  [ -n "$recorded_before" ] || die "applied state holds no record for $guest_path before the rollback"
  [ "$recorded_before" = "$linked_before" ] || die "applied state does not match the published link before the rollback"
  base_target="$recorded_before"

  variant="$(vm_build_variant_toplevel "$source" "$destination")"
  [ "$variant" != "$VM_TOPLEVEL" ] || die "variant generation is identical to the tested generation"
  variant_target="$(nix eval --json "${destination}#nixosConfigurations.furnish-vm.config.lexicon.furnish.manifestData" \
    | jq -r --arg destination "$guest_path" '.[]|select(.filesystemIdentity.destination==$destination)|.retainedArtifactTarget')"
  [ -n "$variant_target" ] && [ "$variant_target" != "$base_target" ] \
    || die "variant generation did not produce a different retained target"
  vm_copy_toplevel "$variant"

  # boot selection rather than activation, so the reconcile happens once and the
  # decision belongs to the boot service. the recorded target is still live here,
  # so this is the update branch.
  ssh_root nix-env -p /nix/var/nix/profiles/system --set "$variant"
  ssh_root "$variant/bin/switch-to-configuration" boot
  ssh_root ln -sfn "$variant" /nix/var/nix/gcroots/program-files-regression/system
  vm_reboot
  [ "$(ssh_vm readlink -f /run/current-system)" = "$variant" ] || die "guest did not boot the variant generation"
  update_result="$(ssh_root systemctl show -p Result --value furnish.service)"
  [ "$update_result" = success ] || die "furnish did not finish cleanly on the update boot (Result=$update_result)"
  linked_updated="$(ssh_vm readlink -- "$guest_path")"
  [ "$linked_updated" = "$variant_target" ] || die "owned update did not republish to the variant target: $linked_updated"
  ssh_vm test -e "$linked_updated" || die "updated link does not resolve"
  recorded_updated="$(vm_ledger_field "$ledger" "$guest_path" appliedArtifactTarget)"
  [ "$recorded_updated" = "$variant_target" ] || die "applied state did not advance on the owned update"
  branch_updated="$(vm_ledger_field "$ledger" "$guest_path" appliedBy)"
  [ "$branch_updated" = update ] || die "applied state recorded $branch_updated where the update branch ran"

  # the rollback boot runs a generation that declares furnish off, so there is no
  # unit and no activation for the collection below to race. the precondition is
  # made of configuration rather than of a runtime poke at the init system, which
  # is the only kind that survives this guest wiping its root.
  disabled="$(vm_build_disabled_toplevel "$source")"
  { [ "$disabled" != "$VM_TOPLEVEL" ] && [ "$disabled" != "$variant" ]; } \
    || die "disabled generation is identical to a generation already under test"
  vm_copy_toplevel "$disabled"
  ssh_root nix-env -p /nix/var/nix/profiles/system --set "$disabled"
  ssh_root "$disabled/bin/switch-to-configuration" boot
  # the variant has to stop being rooted or the collection cannot reach its
  # artifact, and a reap that never could have happened proves nothing. the tested
  # generation keeps its root, and its target is where the repair has to land.
  ssh_root ln -sfn "$VM_TOPLEVEL" /nix/var/nix/gcroots/program-files-regression/system
  vm_reboot
  [ "$(ssh_vm readlink -f /run/current-system)" = "$disabled" ] || die "guest did not boot the disabled generation"
  inert_load_state="$(ssh_root systemctl show -p LoadState --value furnish.service)"
  [ "$inert_load_state" = not-found ] || die "disabled generation still has a furnish unit (LoadState=$inert_load_state)"
  linked_intermediate="$(ssh_vm readlink -- "$guest_path")"
  [ "$linked_intermediate" = "$variant_target" ] || die "inert boot reconciled anyway: $linked_intermediate"

  # the variant is an unrooted older profile generation by now, so its artifact
  # becomes unreachable without anything being forced.
  ssh_root nix-collect-garbage -d >/dev/null
  if ssh_vm test -e "$variant_target"; then die "ordinary garbage collection did not reap the rolled-back target"; fi
  ssh_vm test -e "$base_target" || die "the rooted tested generation lost its target to the collection"
  [ "$(ssh_vm readlink -- "$guest_path")" = "$variant_target" ] || die "link moved while furnish was inert"

  # a dangling link whose target still matches the record is the repair branch.
  ssh_root nix-env -p /nix/var/nix/profiles/system --set "$VM_TOPLEVEL"
  ssh_root "$VM_TOPLEVEL/bin/switch-to-configuration" boot
  vm_reboot
  [ "$(ssh_vm readlink -f /run/current-system)" = "$VM_TOPLEVEL" ] || die "guest did not return to the tested generation"
  repair_result="$(ssh_root systemctl show -p Result --value furnish.service)"
  [ "$repair_result" = success ] || die "furnish did not finish cleanly after the reap (Result=$repair_result)"
  linked_after="$(ssh_vm readlink -- "$guest_path")"
  [ "$linked_after" = "$base_target" ] || die "link was not repaired to the earlier target: $linked_after"
  ssh_vm test -e "$linked_after" || die "repaired link does not resolve"
  recorded_after="$(vm_ledger_field "$ledger" "$guest_path" appliedArtifactTarget)"
  [ "$recorded_after" = "$base_target" ] || die "applied state did not advance to the repaired target"
  branch_after="$(vm_ledger_field "$ledger" "$guest_path" appliedBy)"
  [ "$branch_after" = repair ] || die "applied state recorded $branch_after where the repair branch ran"

  jq -n --arg baseTarget "$base_target" --arg variantTarget "$variant_target" \
    --arg linkedUpdated "$linked_updated" --arg linkedAfter "$linked_after" \
    --arg recordedUpdated "$recorded_updated" --arg recordedAfter "$recorded_after" \
    --arg branchUpdated "$branch_updated" --arg branchAfter "$branch_after" \
    --arg updateUnitResult "$update_result" --arg repairUnitResult "$repair_result" \
    --arg baseToplevel "$VM_TOPLEVEL" --arg variantToplevel "$variant" --arg disabledToplevel "$disabled" \
    '{schemaVersion:1,status:"pass",twoGenerations:true,baseToplevel:$baseToplevel,variantToplevel:$variantToplevel,disabledToplevel:$disabledToplevel,baseTarget:$baseTarget,variantTarget:$variantTarget,updatedWhileRecordedTargetLive:($linkedUpdated==$variantTarget),updateUnitResult:$updateUnitResult,updateLedgerAdvanced:($recordedUpdated==$variantTarget),updateRecordedBranch:$branchUpdated,inertAcrossIntermediateBoot:true,furnishUnitAbsentWhileInert:true,reapedByOrdinaryGc:true,ignoreLivenessUsed:false,repairedAfterGc:($linkedAfter==$baseTarget),repairUnitResult:$repairUnitResult,ledgerRecordAdvanced:($recordedAfter==$baseTarget),repairRecordedBranch:$branchAfter}' \
    | ssh_vm 'cat > /home/tester/.cache/lexicon-furnish-regression/furnish-gc-repair.json'
  log "two-generation proof: updated to $variant_target while it was live, repaired to $base_target after the reap"
}

vm_collect_evidence() {
  local destination="$1"
  mkdir -p "$destination"
  scp_from_vm "$VM_USER@localhost:/home/tester/.cache/lexicon-furnish-regression/*.json" "$destination/"
}

vm_equivalence() {
  local evidence="$1" output="$2" expected vm status
  local vm_expected boot_ids switches persistence generations fixtures gc_survival gc_repair ledger_survival all_true
  expected="$(expected_matrix | jq -Sc .)"
  vm="$(normalize_matrix "$evidence/repair-matrix.json" | jq -Sc .)"
  vm_expected=false; [ "$vm" = "$expected" ] && vm_expected=true
  boot_ids="$(jq -s 'length==3 and all(.[];.bootIdChanged==true and .homePersistence=="persisted")' "$evidence"/case-*-boot-evidence.json)"
  ledger_survival="$(jq -s 'length==3 and all(.[];.ledgerSurvived==true and .ledgerRecordStable==true)' "$evidence"/case-*-boot-evidence.json)"
  switches="$(jq -s 'length==3 and all(.[];.byteIdenticalToplevel==true)' "$evidence"/case-*-switch-evidence.json)"
  persistence="$(jq -s 'length==3 and all(.[];.negativeControlPassed==true and .persistedSentinelSurvived==true and .persistedSentinelUnchanged==true and .persistedEvidenceSetSurvived==true)' "$evidence"/case-*-persistence-evidence.json)"
  generations="$(jq -s 'length==3 and all(.[];.exactGenerationSelected==true and .systemRootPresent==true and .harnessRootPresent==true)' "$evidence"/case-*-generation-evidence.json)"
  fixtures="$(jq -s 'length==3 and all(.[];.fixtureStateValid==true)' "$evidence"/case-*-boot-evidence.json)"
  gc_survival="$(jq -e '.status=="pass" and .positiveGcRun==true and .exactTargetSurvived==true and .targetExistsAfterGc==true and .rootPresentAfter==true' "$evidence/furnish-gc-survival.json" >/dev/null && printf true || printf false)"
  gc_repair="$(jq -e '.status=="pass" and .twoGenerations==true and .updatedWhileRecordedTargetLive==true and .updateLedgerAdvanced==true and .inertAcrossIntermediateBoot==true and .reapedByOrdinaryGc==true and .repairedAfterGc==true and .ledgerRecordAdvanced==true' "$evidence/furnish-gc-repair.json" >/dev/null && printf true || printf false)"
  all_true=false
  if [ "$vm_expected" = true ] && [ "$boot_ids" = true ] && [ "$switches" = true ] && [ "$persistence" = true ] && [ "$generations" = true ] && [ "$fixtures" = true ] && [ "$gc_survival" = true ] && [ "$gc_repair" = true ] && [ "$ledger_survival" = true ]; then all_true=true; fi
  status=finding; [ "$all_true" = true ] && status=pass
  jq -S -n --arg status "$status" --argjson expected "$expected" --argjson vm "$vm" \
    --arg archive "$VM_ARCHIVE" --arg testedToplevel "$VM_TOPLEVEL" --arg regressionApp "$VM_APP" \
    --argjson vmMatchesExpected "$vm_expected" --argjson changedBootIds "$boot_ids" \
    --argjson byteIdenticalSwitches "$switches" --argjson persistenceControls "$persistence" \
    --argjson exactGenerationSelected "$generations" --argjson fixtureStates "$fixtures" \
    --argjson positiveGcSurvival "$gc_survival" --argjson twoGenerationGcRepair "$gc_repair" \
    --argjson ledgerSurvivedRootWipe "$ledger_survival" \
    '{schemaVersion:1,status:$status,authority:{expectedMatrix:$expected},vmEvidence:{matrix:$vm,archive:$archive,testedToplevel:$testedToplevel,regressionApp:$regressionApp},invariants:{vmMatchesExpected:$vmMatchesExpected,changedBootIds:$changedBootIds,byteIdenticalNoOpSwitches:$byteIdenticalSwitches,persistenceAndNegativeControls:$persistenceControls,exactGenerationSelected:$exactGenerationSelected,fixtureStatesValid:$fixtureStates,positiveGcSurvival:$positiveGcSurvival,twoGenerationGcRepair:$twoGenerationGcRepair,ledgerSurvivedRootWipe:$ledgerSurvivedRootWipe}}' > "$output"
  jq . "$output"
  [ "$status" = pass ] || return 1
}


vm_run() {
  local flake="$1"
  vm_require_run
  mkdir -p "$CACHE"
  local output="$CACHE/vm-furnish-proof.json"
  [ -f "$VM_BASE" ] && [ -f "$VM_BASE_VARS" ] && [ -f "$VM_PROVISION" ] || die "lifecycle base is missing; run vm provision once"
  local run_id run_dir evidence archive_json
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  run_dir="$VM_CACHE/program-files-run-$run_id"
  evidence="$CACHE/vm-evidence-$run_id"
  mkdir -p "$run_dir" "$evidence"
  VM_OVERLAY="$run_dir/disk.qcow2"
  VM_RUN_VARS="$run_dir/vars.fd"
  VM_SERIAL="$run_dir/serial.log"
  VM_CODE="$OVMF_FD/FV/OVMF_CODE.fd"
  qemu-img create -f qcow2 -F qcow2 -b "$VM_BASE" "$VM_OVERLAY" >/dev/null
  cp "$VM_BASE_VARS" "$VM_RUN_VARS"
  chmod 0600 "$VM_RUN_VARS"
  QEMU_PID=""
  trap 'vm_stop' EXIT
  vm_start
  VM_TEST_FLAKE="$run_dir/source"
  vm_prepare_test_flake "$flake" "$VM_TEST_FLAKE"
  VM_TOPLEVEL="$(nix build --no-link --print-out-paths "${VM_TEST_FLAKE}#nixosConfigurations.furnish-vm.config.system.build.toplevel")"
  VM_COORDINATOR="$(nix build --no-link --print-out-paths "${VM_TEST_FLAKE}#furnish-coordinator")"
  VM_FAULT_COORDINATOR="$(nix build --no-link --print-out-paths "${VM_TEST_FLAKE}#furnish-coordinator-fault-injection")"
  VM_APP="$(nix build --no-link --print-out-paths "${VM_TEST_FLAKE}#program-files-regression")"
  archive_json="$(nix flake archive --json "$VM_TEST_FLAKE")"
  VM_ARCHIVE="$(jq -r .path <<<"$archive_json")"
  [[ "$VM_ARCHIVE" == /nix/store/* ]] || die "flake archive is not an immutable store path"
  vm_copy_closures
  vm_select_toplevel
  vm_reboot
  vm_assert_selected_after_boot initial
  vm_guest_harness furnish-symlink --host furnish-vm
  vm_guest_harness roots --host furnish-vm
  vm_guest_harness runtime-wins-proof --host furnish-vm --coordinator "$VM_COORDINATOR/bin/furnish-coordinator"
  local point
  for point in pre-pending pending-committed stage-written stage-synced published published-synced verified exchange-published; do
    vm_guest_harness fault-prepare --host furnish-vm --point "$point" --coordinator "$VM_FAULT_COORDINATOR/bin/furnish-coordinator"
    vm_guest_harness fault-assert --host furnish-vm --point "$point" --coordinator "$VM_FAULT_COORDINATOR/bin/furnish-coordinator"
  done
  vm_gc_survival
  vm_guest_harness rm-matrix --host furnish-vm
  local mode
  for mode in absent dangling drifted; do
    vm_guest_harness case-prepare --host furnish-vm --mode "$mode"
    vm_noop_switch "$mode"
    vm_guest_harness case-switch-assert --host furnish-vm --mode "$mode"
    vm_guest_harness case-prepare --host furnish-vm --mode "$mode"
    vm_guest_harness_root reboot-prepare --host furnish-vm --mode "$mode" --run-id "$run_id"
    vm_reboot
    vm_assert_selected_after_boot "$mode"
    vm_guest_harness_root reboot-assert --host furnish-vm --mode "$mode" --run-id "$run_id"
    vm_guest_harness case-boot-assert --host furnish-vm --mode "$mode"
  done
  vm_gc_repair_survival "$VM_TEST_FLAKE" "$run_dir/variant-source"
  vm_collect_evidence "$evidence"
  cp "$CACHE/disabled-generation-probe.json" "$evidence/"
  cp "$evidence/repair-matrix.json" "$CACHE/vm-repair-matrix.json"
  vm_equivalence "$evidence" "$output"
  log "VM proof passed; disposable overlay retained at $run_dir"
}

command="${1:-}"
shift || true
case "$command" in
  furnish-symlink)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] || die "furnish-symlink needs --host"
    furnish_symlink "$2";;
  roots)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] || die "roots needs --host"
    roots_check "$2";;
  case-prepare)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] && [ "${3:-}" = --mode ] && [ -n "${4:-}" ] || die "case-prepare needs --host and --mode"
    case_prepare "$2" "$4";;
  case-switch-assert)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] && [ "${3:-}" = --mode ] && [ -n "${4:-}" ] || die "case-switch-assert needs --host and --mode"
    case_switch_assert "$2" "$4";;
  case-boot-assert)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] && [ "${3:-}" = --mode ] && [ -n "${4:-}" ] || die "case-boot-assert needs --host and --mode"
    case_boot_assert "$2" "$4";;
  rm-matrix)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] || die "rm-matrix needs --host"
    require_host "$2"; rm -f "$(matrix_path)";;
  reboot-prepare)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] && [ "${3:-}" = --mode ] && [ -n "${4:-}" ] && [ "${5:-}" = --run-id ] && [ -n "${6:-}" ] || die "reboot-prepare needs --host, --mode, and --run-id"
    reboot_prepare "$2" "$4" "$6";;
  reboot-assert)
    [ "${1:-}" = --host ] && [ -n "${2:-}" ] && [ "${3:-}" = --mode ] && [ -n "${4:-}" ] && [ "${5:-}" = --run-id ] && [ -n "${6:-}" ] || die "reboot-assert needs --host, --mode, and --run-id"
    reboot_assert "$2" "$4" "$6";;
  runtime-wins-proof)
    host=""; coordinator=""
    while [ "$#" -gt 0 ]; do case "$1" in --host) host="$2"; shift 2;; --coordinator) coordinator="$2"; shift 2;; *) die "unknown runtime-wins argument: $1";; esac; done
    [ -n "$host" ] && [ -n "$coordinator" ] || die "runtime-wins-proof needs --host and --coordinator"
    runtime_wins_proof "$host" "$coordinator";;
  fault-prepare|fault-assert)
    host=""; point=""; coordinator=""
    while [ "$#" -gt 0 ]; do case "$1" in --host) host="$2"; shift 2;; --point) point="$2"; shift 2;; --coordinator) coordinator="$2"; shift 2;; *) die "unknown fault argument: $1";; esac; done
    [ -n "$host" ] && [ -n "$point" ] && [ -n "$coordinator" ] || die "$command needs --host, --point, and --coordinator"
    if [ "$command" = fault-prepare ]; then fault_prepare "$host" "$point" "$coordinator"; else fault_assert "$host" "$point" "$coordinator"; fi;;
  vm)
    action="${1:-}"; [ -n "$action" ] || die "vm needs provision or run"; shift
    flake="."
    while [ "$#" -gt 0 ]; do case "$1" in --flake) flake="$2"; shift 2;; *) die "unknown vm $action argument: $1";; esac; done
    case "$action" in provision) vm_provision "$flake";; run) vm_run "$flake";; *) die "unknown vm action: $action";; esac;;
  -h|--help|help|"") usage;;
  *) die "unknown command: $command";;
esac