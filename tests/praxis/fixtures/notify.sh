#!/usr/bin/env bash
set -euo pipefail
jq="$1"
shift
secret=false
if [[ -v PRAXIS_TEST_TOKEN ]]; then
  secret=true
fi
args="$($jq -cn --args '$ARGS.positional' -- "$@")"
$jq -cn --argjson args "$args" --argjson secret "$secret" \
  '[$args, $secret]' > notification
