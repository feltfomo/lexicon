#!/usr/bin/env bash
set -euo pipefail
printf 'script\n' >> trace
printf '%s\0' "$@" > args.actual
printf 'fixture stdout\n'
printf 'fixture stderr\n' >&2
