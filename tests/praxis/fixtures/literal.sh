#!/usr/bin/env bash
set -euo pipefail
args="$(${JQ:-jq} -cn --args '$ARGS.positional' -- "$@")"
${JQ:-jq} -cn \
  --argjson args "$args" \
  --arg colorize "$PRAXIS_ARG_COLORIZE" \
  --arg destination "$PRAXIS_ARG_DESTINATION" \
  '[$args, $colorize, $destination]'
