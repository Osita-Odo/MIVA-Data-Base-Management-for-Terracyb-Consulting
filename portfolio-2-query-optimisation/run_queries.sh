#!/usr/bin/env bash
# Runs every query and saves its result set to results/query-results/<query>.txt
# Usage: ./run_queries.sh [database]      (default database: ead)
set -euo pipefail                      # stop on the first error
DB="${1:-ead}"
cd "$(dirname "$0")"
export PGOPTIONS="-c search_path=ead"  # queries use table names without the ead. prefix
mkdir -p results/query-results

# One output file per query, named after the query file
for f in queries/*.sql; do
    name=$(basename "$f" .sql)
    echo "Running $name"
    psql -d "$DB" -X -v ON_ERROR_STOP=1 -f "$f" > "results/query-results/$name.txt"
done
echo "Results saved in results/query-results/"
