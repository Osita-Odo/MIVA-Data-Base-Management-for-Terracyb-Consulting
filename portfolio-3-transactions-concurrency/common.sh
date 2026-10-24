#!/usr/bin/env bash
# Shared settings for the concurrency demos.
# Connection comes from the usual PGHOST / PGPORT / PGUSER / PGPASSWORD variables.
set -uo pipefail
DB="${PGDATABASE:-ead}"
export PGOPTIONS="-c search_path=ead -c client_min_messages=warning"
OUT_DIR="$(dirname "$0")/output"
mkdir -p "$OUT_DIR"

# psql for one simulated user: quiet, no .psqlrc, shows errors but keeps going
session () { psql -d "$DB" -X -q -v ON_ERROR_STOP=0 "$@"; }

# psql for setup queries that return a single value
value () { psql -d "$DB" -X -tA -c "$1"; }
