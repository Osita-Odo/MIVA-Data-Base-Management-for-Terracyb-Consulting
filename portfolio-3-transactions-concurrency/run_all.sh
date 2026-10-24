#!/usr/bin/env bash
# Runs all five scenarios and saves their output to output/
cd "$(dirname "$0")"          # run from this folder, wherever it is called from
mkdir -p output
# Scenarios 1 and 2 are single-session SQL scripts; 2>&1 keeps the expected
# errors in the log, because they are part of the evidence.
psql -d "${PGDATABASE:-ead}" -X -f 01_commit_close_finding.sql  > output/01_commit_close_finding.log 2>&1
psql -d "${PGDATABASE:-ead}" -X -f 02_rollback_overpayment.sql > output/02_rollback_overpayment.log 2>&1
# Scenarios 3-5 start two parallel sessions and write their own logs
./03_lost_update.sh
./04_isolation_levels.sh
./05_deadlock.sh
echo "All logs saved in output/"
