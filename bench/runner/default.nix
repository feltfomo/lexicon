# the comparison runner. it only resolves sources, launches the pinned
# evaluator, enforces timeouts and collects files. enumeration, projection
# checks, aggregation and the report are nix, in the workload catalog and in
# bench/analysis, evaluated by the same evaluator over what this collects
{ pkgs, evaluator }:
pkgs.writeShellApplication {
  name = "lexicon-bench";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.time
    pkgs.git
  ];
  text = ''
    nix=${evaluator}/bin/nix
    source_nix=${./source.nix}
    features=(--extra-experimental-features "nix-command flakes pipe-operators")

    usage() {
      cat >&2 <<'EOF'
    usage
      lexicon-bench compare --baseline REV --candidate REV|worktree [options]
      lexicon-bench report DIR

    compare options
      --repo DIR           repository holding both revisions (default: current directory)
      --output DIR         new directory for records and the report (default: XDG_CACHE_HOME/lexicon-bench/TIME)
      --workloads REGEX    bash regex over workload names (default: every runnable workload)
      --sizes "4 16 64"    sizes to run (default: 4 16 64)
      --timeout SECONDS    per-sample limit, enforced with SIGKILL (default: 600)

    worktree names the repository's working tree. a baseline must be clean.
    EOF
      exit 2
    }

    refuse() {
      echo "lexicon-bench: refused, $*" >&2
      exit 3
    }

    evaluate() {
      "$nix" "''${features[@]}" eval "$@"
    }

    evaluator_version="$("$nix" --version)"
    evaluator_version="''${evaluator_version##* }"

    report() {
      local dir="$1"
      evaluate --raw --impure --expr "
        let
          dir = /. + \"$dir\";
          run = builtins.fromJSON (builtins.readFile (dir + \"/run.json\"));
          candidate = builtins.getFlake (import (run.bench + \"/bench/runner/reference.nix\") run.candidate);
        in
        import (run.bench + \"/bench/analysis/report.nix\") {
          inherit dir;
          inherit (candidate.inputs.nixpkgs) lib;
        }"
    }

    if [[ $# -lt 1 ]]; then usage; fi
    command="$1"
    shift

    if [[ "$command" == report ]]; then
      [[ $# -eq 1 && -f "$1/run.json" ]] || usage
      dir="$(realpath "$1")"
      report "$dir" > "$dir/report.md"
      cat "$dir/report.md"
      exit 0
    fi
    [[ "$command" == compare ]] || usage

    repo="$PWD"
    baseline_spec=""
    candidate_spec=""
    output=""
    pattern=""
    sizes="4 16 64"
    timeout_seconds=600
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --baseline) baseline_spec="$2"; shift 2 ;;
        --candidate) candidate_spec="$2"; shift 2 ;;
        --repo) repo="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --workloads) pattern="$2"; shift 2 ;;
        --sizes) sizes="$2"; shift 2 ;;
        --timeout) timeout_seconds="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ -n "$baseline_spec" && -n "$candidate_spec" ]] || usage
    [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || usage
    for size in $sizes; do [[ "$size" =~ ^[0-9]+$ ]] || usage; done

    top="$(git -C "$repo" rev-parse --show-toplevel)"
    common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)"
    # records stay out of the tree by default, since every path:. command copies
    # the tree into the store and a full run holds hundreds of statistics files
    if [[ -z "$output" ]]; then output="''${XDG_CACHE_HOME:-$HOME/.cache}/lexicon-bench/$(date -u +%Y%m%dT%H%M%SZ)"; fi
    output="$(realpath -m "$output")"
    if [[ -e "$output" ]]; then refuse "output $output already exists"; fi

    # sets side_revision, side_dirty, side_source and side_hash for one side
    resolve() {
      local role="$1" spec="$2" resolved
      if [[ "$spec" == worktree ]]; then
        side_revision="$(git -C "$top" rev-parse HEAD)"
        side_dirty=false
        if [[ -n "$(git -C "$top" status --porcelain)" ]]; then side_dirty=true; fi
        if [[ "$role" == baseline && "$side_dirty" == true ]]; then
          refuse "the baseline working tree $top has uncommitted changes"
        fi
        resolved="$(evaluate --raw --impure --expr "import $source_nix { location = \"$top\"; }")"
      else
        side_revision="$(git -C "$top" rev-parse --verify --quiet "$spec^{commit}")" ||
          refuse "$role $spec is not a revision of $top"
        side_dirty=false
        resolved="$(evaluate --raw --impure --expr "import $source_nix { location = \"''${common%/.git}\"; revision = \"$side_revision\"; }")"
      fi
      side_source="''${resolved% *}"
      side_hash="''${resolved#* }"
    }

    side_json() {
      printf '{"spec":"%s","revision":"%s","dirty":%s,"source":"%s","narHash":"%s"}' \
        "$1" "$side_revision" "$side_dirty" "$side_source" "$side_hash"
    }

    resolve baseline "$baseline_spec"
    baseline_source="$side_source"
    baseline_hash="$side_hash"
    baseline_json="$(side_json "$baseline_spec")"
    resolve candidate "$candidate_spec"
    candidate_source="$side_source"
    candidate_hash="$side_hash"
    candidate_json="$(side_json "$candidate_spec")"

    locked() {
      printf '{ source = "%s"; narHash = "%s"; }' "$1" "$2"
    }
    candidate_locked="$(locked "$candidate_source" "$candidate_hash")"
    bench="(builtins.fetchTree { type = \"path\"; path = \"$candidate_source\"; narHash = \"$candidate_hash\"; }).outPath"
    reference="import ($bench + \"/bench/runner/reference.nix\")"
    system="$(evaluate --raw --impure --expr builtins.currentSystem)"

    # both sides run under the candidate's evaluator, so a runner built from any
    # other pin would measure something the candidate didn't choose. this check
    # uses the runner's own reference, since a candidate without the bench tree
    # has to be refused here rather than fail on a missing file
    candidate_evaluator="$(evaluate --raw --impure --expr "
      (builtins.getFlake (import ${./reference.nix} $candidate_locked)).packages.$system.bench-evaluator.outPath or \"none\"")"
    if [[ "$candidate_evaluator" != "${evaluator}" ]]; then
      refuse "the candidate pins bench-evaluator $candidate_evaluator, this runner launches ${evaluator}"
    fi

    # nothing is written until every refusal has had its chance
    mkdir -p "$output/cells"

    printf '{"baseline":%s,"candidate":%s,"bench":"%s","system":"%s","timeoutSeconds":%s,"evaluator":{"version":"%s","outPath":"%s"}}\n' \
      "$baseline_json" "$candidate_json" "$candidate_source" "$system" "$timeout_seconds" \
      "$evaluator_version" "${evaluator}" > "$output/run.json"

    mapfile -t workloads < <(evaluate --raw --expr "
      builtins.concatStringsSep \"\n\" (import ($bench + \"/bench/workloads\")).runnable")
    mapfile -t schedule < <(evaluate --raw --expr "
      builtins.concatStringsSep \"\n\" (map (step: step.phase + \":\" + step.side) (import ($bench + \"/bench/runner/schedule.nix\")))")
    selected=()
    for workload in "''${workloads[@]}"; do
      if [[ -z "$pattern" || "$workload" =~ $pattern ]]; then selected+=("$workload"); fi
    done
    [[ ''${#selected[@]} -gt 0 ]] || refuse "no runnable workload matches $pattern"

    echo "lexicon-bench: ''${#selected[@]} workloads at sizes $sizes into $output" >&2

    # one sample. the counting variables reach the evaluator alone, and timeout
    # sends sigkill because the evaluator only checks for interrupts outside its
    # evaluation loop
    sample() {
      local dir="$1" workload="$2" size="$3" order="$4" phase="$5" side="$6" source hash
      if [[ "$side" == baseline ]]; then
        source="$baseline_source"
        hash="$baseline_hash"
      else
        source="$candidate_source"
        hash="$candidate_hash"
      fi
      mkdir -p "$dir"
      local machine load start end status=0 timed_out=false rss=null
      machine="$(uname -n)"
      read -r load _ < /proc/loadavg
      start="$(date +%s%N)"
      env NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$dir/stats.json" NIX_COUNT_CALLS=1 \
        time --quiet --format '%M' --output "$dir/rss" \
        timeout --signal KILL "$timeout_seconds" \
        "$nix" "''${features[@]}" eval --json --expr "
          let bench = $bench; in
          import (bench + \"/bench/runner/sample.nix\") {
            bench = bench + \"/bench\";
            source = $reference $(locked "$source" "$hash");
            workload = \"$workload\";
            size = $size;
            system = \"$system\";
          }" > "$dir/stdout.json" 2> "$dir/stderr.log" || status=$?
      end="$(date +%s%N)"
      if [[ $status -eq 124 || $status -eq 137 ]]; then timed_out=true; fi
      # only a successful sample's stdout is a projection
      if [[ $status -eq 0 ]]; then mv "$dir/stdout.json" "$dir/output.json"; fi
      if [[ -s "$dir/rss" ]]; then rss="$(tail -n 1 "$dir/rss")"; fi
      [[ "$rss" =~ ^[0-9]+$ ]] || rss=null
      printf '{"workload":"%s","size":%s,"order":%s,"phase":"%s","side":"%s","exit":%s,"timedOut":%s,"wallNs":%s,"peakRssKiB":%s,"machine":"%s","load":%s,"source":"%s","evaluator":{"version":"%s","outPath":"%s"}}\n' \
        "$workload" "$size" "$order" "$phase" "$side" "$status" "$timed_out" "$((end - start))" "$rss" \
        "$machine" "$load" "$source" "$evaluator_version" "${evaluator}" > "$dir/meta.json"
      return "$status"
    }

    for workload in "''${selected[@]}"; do
      for size in $sizes; do
        cell="$output/cells/$workload/$size"
        order=0
        for step in "''${schedule[@]}"; do
          phase="''${step%%:*}"
          side="''${step#*:}"
          # a failed sample rejects its cell, so the rest of the cell isn't run
          if ! sample "$cell/$order-$phase-$side" "$workload" "$size" "$order" "$phase" "$side"; then
            echo "lexicon-bench: $workload at $size failed in sample $order, see $cell" >&2
            break
          fi
          order=$((order + 1))
        done
        echo "lexicon-bench: $workload at $size done" >&2
      done
    done

    report "$output" > "$output/report.md"
    cat "$output/report.md"
  '';
}
