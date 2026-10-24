#!/usr/bin/env bash
# =====================================================================
# Portfolio 5: replication and failover demo (PostgreSQL)
# Prerequisite: docker compose up -d   (all containers healthy)
# Usage: ./replication_failover_demo.sh 2>&1 | tee output/replication_failover.log
#
# Steps
#   1. Status of primary and replica
#   2. Write on the primary, read it on the replica (replication works)
#   3. Writes on the replica are refused (read-only standby)
#   4. Stop the primary: replica still serves reads, nothing accepts writes
#   5. Promote the replica: it becomes the new primary and accepts writes
# =====================================================================
set -uo pipefail
P="docker exec -i pg-primary psql -U postgres -d ead -X"
R="docker exec -i pg-replica psql -U postgres -d ead -X"
step () { echo; echo "=== $(date +%T) $* ==="; }

step "1. Replication status on the primary"
$P -f /sql/replication_status_primary.sql
step "1. Replication status on the replica"
$R -f /sql/replication_status_replica.sql

step "2. Insert a new client office on the PRIMARY"
$P -c "INSERT INTO ead.office (office_name, city, country_code, region)
       VALUES ('TerraCyber Accra', 'Accra', 'GH', 'AFRICA')
       ON CONFLICT (city, country_code) DO NOTHING;"
sleep 1
step "2. Read it from the REPLICA one second later"
$R -c "SELECT office_id, office_name, city FROM ead.office ORDER BY office_id;"

step "3. Try to write on the REPLICA (expected: read-only error)"
$R -c "INSERT INTO ead.office (office_name, city, country_code, region)
       VALUES ('Should fail', 'Nowhere', 'ZZ', 'OTHER');"

step "4. Simulate a primary failure: docker stop pg-primary"
docker stop pg-primary
sleep 3
step "4. Replica still answers reads"
$R -c "SELECT count(*) AS findings_readable FROM ead.finding;"
step "4. ... but it is still a standby, so writes fail"
$R -c "SELECT pg_is_in_recovery() AS still_standby;"
$R -c "UPDATE ead.finding SET status = 'in_progress' WHERE finding_id = (SELECT min(finding_id) FROM ead.finding WHERE status = 'open');"

step "5. Promote the replica (manual failover)"
START=$(date +%s.%N)
$R -c "SELECT pg_promote(wait => true, wait_seconds => 30) AS promoted;"
END=$(date +%s.%N)
echo "Promotion took $(awk -v s="$START" -v e="$END" 'BEGIN { printf "%.2f", e - s }') seconds"
$R -c "SELECT pg_is_in_recovery() AS still_standby;"
step "5. The new primary accepts writes"
$R -c "UPDATE ead.finding SET status = 'in_progress' WHERE finding_id = (SELECT min(finding_id) FROM ead.finding WHERE status = 'open') RETURNING finding_id, status;"

echo
echo "Done. To rebuild the original topology run: docker compose down -v && docker compose up -d"
