# the comparison runner. it only resolves sources, launches the pinned
# evaluator, enforces timeouts and collects files. enumeration, projection
# checks, aggregation and the report are nix, in the workload catalog and in
# bench/analysis, evaluated by the same evaluator over what this collects
{ pkgs, evaluator }:
pkgs.writeShellApplication {
  name = "lexicon-bench";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.gzip
    pkgs.time
    pkgs.git
  ];
  text = ''
    nix=${evaluator}/bin/nix
    source_nix=${./source.nix}
    reference_nix=${./reference.nix}
    calibrate_nix=${../.}/analysis/calibrate.nix
    features=(--extra-experimental-features "nix-command flakes pipe-operators")
    # samples a second at most. the profiler only samples on function entry
    profile_frequency=1000

    usage() {
      cat >&2 <<'EOF'
    usage
      lexicon-bench compare --baseline REV --candidate REV|worktree [options]
      lexicon-bench report DIR
      lexicon-bench calibrate DIR...
      lexicon-bench reduce PROFILE [NAME...]

    compare and report exit 1 when the verdict fails or the budgets can't judge
    the records' evaluator. calibrate prints budgets from runs that compared one
    revision with itself. reduce prints the inclusive samples of each named
    frame in a folded profile, as compare records them.

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

    field() {
      evaluate --raw --impure --expr "(builtins.fromJSON (builtins.readFile (/. + \"$1\"))).$2"
    }

    # a fleet's folded stacks run to hundreds of megabytes, more than the
    # analysis can read, so each profile is reduced here to the samples of every
    # stack and of the stacks holding each marker name's frame, once per stack.
    # a lambda frame ends in its name, followed by the next frame or the count
    reduce() {
      awk -v names="$2" '
        BEGIN { n = split(names, wanted, " ") }
        function malformed(reason) {
          print "lexicon-bench: malformed profile line " NR ", " reason > "/dev/stderr"
          failed = 1
          exit 1
        }
        {
          if (RT != "\n") malformed("profile ends inside a line")
          if (!match($0, /^(.*) ([1-9][0-9]*)$/, record) || record[1] == "") malformed("missing positive sample count")
          depth = split(record[1], frames, ";")
          for (frame = 1; frame <= depth; frame++) {
            if (frames[frame] == "") malformed("empty frame")
            if (match(frames[frame], /:[0-9]+(:|$)/)) {
              position = substr(frames[frame], RSTART + 1)
              split(position, parts, ":")
              if (parts[1] !~ /^(0|[1-9][0-9]*)$/) malformed("invalid line position")
              remainder = substr(position, length(parts[1]) + 2)
              if (remainder ~ /^[0-9]+(:|$)/ && parts[2] !~ /^[1-9][0-9]*$/) malformed("invalid column position")
            }
          }
          total += record[2]
          for (i = 1; i <= n; i++) {
            if (index($0, ":" wanted[i] ";") || index($0, ":" wanted[i] " ")) inclusive[wanted[i]] += record[2]
          }
        }
        END {
          if (failed) exit 1
          if (NR == 0) { print "lexicon-bench: profile contains no samples" > "/dev/stderr"; exit 1 }
          printf "{\"total\":%d,\"inclusive\":{", total
          for (i = 1; i <= n; i++) printf "%s\"%s\":%d", (i > 1 ? "," : ""), wanted[i], inclusive[wanted[i]]
          printf "}}\n"
        }' "$1"
    }

    # renders report.md for a run directory with the candidate's analysis and exits
    # with its verdict. a candidate from before verdicts renders text alone and judges nothing
    report() {
      local dir="$1" verdict
      evaluate --json --impure --expr "
        let
          dir = /. + \"$dir\";
          run = builtins.fromJSON (builtins.readFile (dir + \"/run.json\"));
          candidate = builtins.getFlake (import (run.bench + \"/bench/runner/reference.nix\") run.candidate);
          rendered = import (run.bench + \"/bench/analysis/report.nix\") {
            inherit dir;
            inherit (candidate.inputs.nixpkgs) lib;
          };
        in
        if builtins.isString rendered then { text = rendered; verdict = \"unjudged\"; } else rendered" \
        > "$dir/report.json"
      field "$dir/report.json" text > "$dir/report.md"
      cat "$dir/report.md"
      verdict="$(field "$dir/report.json" verdict)"
      case "$verdict" in
        pass | unjudged) exit 0 ;;
        fail) echo "lexicon-bench: the candidate regressed, see $dir/report.md" >&2 ;;
        *) echo "lexicon-bench: the budgets can't judge these records, see $dir/report.md" >&2 ;;
      esac
      exit 1
    }

    if [[ $# -lt 1 ]]; then usage; fi
    command="$1"
    shift

    if [[ "$command" == reduce ]]; then
      [[ $# -ge 1 && -f "$1" ]] || usage
      profile="$1"
      shift
      reduce "$profile" "$*"
      exit 0
    fi

    if [[ "$command" == report ]]; then
      [[ $# -eq 1 && -f "$1/run.json" ]] || usage
      report "$(realpath "$1")"
    fi

    # every run must exist before anything is read, and the lib comes from the
    # first run's candidate, as report takes it
    if [[ "$command" == calibrate ]]; then
      [[ $# -ge 1 ]] || usage
      dirs=""
      for dir in "$@"; do
        [[ -f "$dir/run.json" ]] || usage
        dirs+=" (/. + \"$(realpath "$dir")\")"
      done
      first="$(realpath "$1")"
      evaluate --raw --impure --expr "
        let
          run = builtins.fromJSON (builtins.readFile (/. + \"$first/run.json\"));
          candidate = builtins.getFlake (import $reference_nix run.candidate);
        in
        import $calibrate_nix {
          dirs = [ $dirs ];
          inherit (candidate.inputs.nixpkgs) lib;
        }"
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

    mapfile -t workloads < <(evaluate --raw --expr "
      builtins.concatStringsSep \"\n\" (import ($bench + \"/bench/workloads\")).runnable")
    mapfile -t schedule < <(evaluate --raw --expr "
      builtins.concatStringsSep \"\n\" (map (step: step.phase + \":\" + step.side) (import ($bench + \"/bench/runner/schedule.nix\")))")
    schedule_json="$(evaluate --json --expr "import ($bench + \"/bench/runner/schedule.nix\")")"

    # the marker names a side defines, found by the candidate's analysis. only a
    # schedule with profiling samples needs them
    marker_names() {
      evaluate --raw --impure --expr "
        let
          lib = (builtins.getFlake (import $reference_nix $candidate_locked)).inputs.nixpkgs.lib;
          discovered = (import ($bench + \"/bench/analysis/markers.nix\") { inherit lib; }).discover \"$1\";
        in
        builtins.concatStringsSep \" \" (lib.unique (map (marker: marker.name) discovered))"
    }
    baseline_names=""
    candidate_names=""
    if [[ " ''${schedule[*]} " == *" profile:"* ]]; then
      baseline_names="$(marker_names "$baseline_source")"
      candidate_names="$(marker_names "$candidate_source")"
    fi

    # nothing is written until every refusal has had its chance
    mkdir -p "$output/cells"

    # the schedule is recorded because the analysis checks cells against what ran,
    # which an older candidate's catalog may have shaped differently
    printf '{"baseline":%s,"candidate":%s,"bench":"%s","system":"%s","timeoutSeconds":%s,"schedule":%s,"profileFrequency":%s,"evaluator":{"version":"%s","outPath":"%s"}}\n' \
      "$baseline_json" "$candidate_json" "$candidate_source" "$system" "$timeout_seconds" \
      "$schedule_json" "$profile_frequency" "$evaluator_version" "${evaluator}" > "$output/run.json"
    selected=()
    for workload in "''${workloads[@]}"; do
      if [[ -z "$pattern" || "$workload" =~ $pattern ]]; then selected+=("$workload"); fi
    done
    [[ ''${#selected[@]} -gt 0 ]] || refuse "no runnable workload matches $pattern"

    echo "lexicon-bench: ''${#selected[@]} workloads at sizes $sizes into $output" >&2

    # one sample. the counting variables reach the evaluator alone, and timeout
    # sends sigkill because the evaluator only checks for interrupts outside its
    # evaluation loop. a profiling sample clears them and a counting sample turns
    # the profiler off, so an inherited setting can't combine the two
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
      local machine load start end status=0 timed_out=false rss=null instrument names
      if [[ "$phase" == profile ]]; then
        instrument=(
          -u NIX_SHOW_STATS -u NIX_SHOW_STATS_PATH -u NIX_COUNT_CALLS
          "$nix" "''${features[@]}" eval
          --option eval-profiler flamegraph
          --option eval-profiler-frequency "$profile_frequency"
          --option eval-profile-file "$dir/profile.folded"
        )
      else
        instrument=(
          NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$dir/stats.json" NIX_COUNT_CALLS=1
          "$nix" "''${features[@]}" eval
          --option eval-profiler disabled
        )
      fi
      machine="$(uname -n)"
      read -r load _ < /proc/loadavg
      start="$(date +%s%N)"
      # gnu time, since the bash keyword can't write peak rss to a file
      command time --quiet --format '%M' --output "$dir/rss" \
        timeout --signal KILL "$timeout_seconds" \
        env "''${instrument[@]}" --json --expr "
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
      # the raw stacks stay beside the reduction for flame graphs, compressed
      if [[ $status -eq 0 && "$phase" == profile && -f "$dir/profile.folded" ]]; then
        if [[ "$side" == baseline ]]; then names="$baseline_names"; else names="$candidate_names"; fi
        if ! reduce "$dir/profile.folded" "$names" > "$dir/profile.json" 2> "$dir/profile-error.log"; then
          status=1
        fi
        gzip -9 "$dir/profile.folded"
      fi
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

    report "$output"
  '';
}
