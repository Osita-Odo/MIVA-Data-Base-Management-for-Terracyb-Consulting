#!/usr/bin/env bash
# =====================================================================
# Portfolio 5: replication and failover demo (PostgreSQL)
# Lagos is the primary; Port Harcourt is its disaster-recovery standby.
# Prerequisite: docker compose up -d   (all containers healthy)
# Usage: ./replication_failover_demo.sh 2>&1 | tee output/replication_failover.log
#
# Steps
#   1. Status of the Lagos primary and the Port Harcourt replica
#   2. Write in Lagos, read it in Port Harcourt (replication works)
#   3. Writes in Port Harcourt are refused (read-only standby)
#   4. Lagos goes down: Port Harcourt still serves reads, nothing accepts writes
#   5. Promote Port Harcourt: it becomes the new primary and accepts writes
# =====================================================================
set -uo pipefail                                  # no -e: some steps are EXPECTED to fail
P="docker exec -i pg-lagos psql -U postgres -d ead -X"          # primary
R="docker exec -i pg-portharcourt psql -U postgres -d ead -X"   # replica
step () { echo; echo "=== $(date +%T) $* ==="; }

step "1. Replication status on the Lagos primary"
$P -f /sql/replication_status_primary.sql
step "1. Replication status on the Port Harcourt replica"
$R -f /sql/replication_status_replica.sql

step "2. Register a new client on the PRIMARY (Lagos)"
$P -c "INSERT INTO ead.client (name, sector, state_code)
       VALUES ('Jos Plateau Solar Cooperative', 'ngo', 'PL')
       ON CONFLICT (name) DO NOTHING;"
sleep 1                                          # allow time for WAL to stream
step "2. Read it from the REPLICA (Port Harcourt) one second later"
$R -c "SELECT client_id, name, state_code FROM ead.client ORDER BY client_id DESC LIMIT 3;"

step "3. Try to write on the REPLICA (expected: read-only error)"
$R -c "INSERT INTO ead.client (name, sector, state_code)
       VALUES ('Should fail', 'private', 'RI');"

step "4. Simulate losing the Lagos site: docker stop pg-lagos"
docker stop pg-lagos
sleep 3
step "4. Port Harcourt still answers reads"
$R -c "SELECT count(*) AS findings_readable FROM ead.finding;"
step "4. ... but it is still a standby, so writes fail"
$R -c "SELECT pg_is_in_recovery() AS still_standby;"
$R -c "UPDATE ead.finding SET status = 'in_progress' WHERE finding_id = (SELECT min(finding_id) FROM ead.finding WHERE status = 'open');"

step "5. Promote Port Harcourt (manual failover)"
START=$(date +%s.%N)
$R -c "SELECT pg_promote(wait => true, wait_seconds => 30) AS promoted;"
END=$(date +%s.%N)
echo "Promotion took $(awk -v s="$START" -v e="$END" 'BEGIN { printf "%.2f", e - s }') seconds"
$R -c "SELECT pg_is_in_recovery() AS still_standby;"
step "5. The new primary in Port Harcourt accepts writes"
$R -c "UPDATE ead.finding SET status = 'in_progress' WHERE finding_id = (SELECT min(finding_id) FROM ead.finding WHERE status = 'open') RETURNING finding_id, status;"

echo
echo "Done. To rebuild the original topology run: docker compose down -v && docker compose up -d"
