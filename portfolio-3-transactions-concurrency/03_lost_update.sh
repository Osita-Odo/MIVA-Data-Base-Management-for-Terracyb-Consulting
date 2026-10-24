#!/usr/bin/env bash
# =====================================================================
# Scenario 3: LOST UPDATE and its fix with SELECT ... FOR UPDATE
# Two engagement managers add hours to the same consultant at once.
#   Manager A adds 10 hours, Manager B adds 5 hours. Correct total: +15.
# Run 1: plain read then write (READ COMMITTED) -> B's change is lost.
# Run 2: row lock with FOR UPDATE -> B waits for A, total is correct.
# Why FOR UPDATE (D46): each manager reads the hours, decides, then writes.
# A row lock protects this read-decide-write pattern; an atomic
# "hours = hours + 5" would also work, but only when no decision is needed.
# =====================================================================
source "$(dirname "$0")/common.sh"
LOG="$OUT_DIR/03_lost_update.log"
main () {

E=$(value "SELECT engagement_id FROM engagement_staff WHERE role_on_engagement = 'Engagement lead' ORDER BY engagement_id LIMIT 1")
C=$(value "SELECT consultant_id FROM engagement_staff WHERE engagement_id = $E AND role_on_engagement = 'Engagement lead'")
ROW="engagement_id = $E AND consultant_id = $C"
ORIG=$(value "SELECT hours_allocated FROM engagement_staff WHERE $ROW")

reset_hours () { value "UPDATE engagement_staff SET hours_allocated = 100 WHERE $ROW" > /dev/null; }
show ()  { echo "    Final hours_allocated: $(value "SELECT hours_allocated FROM engagement_staff WHERE $ROW")  (expected 115.0)"; }

run_demo () {   # $1 = "" or "FOR UPDATE"
    local lock="$1"
    reset_hours
    echo "    Start: hours_allocated = 100"
    session <<SQL &
BEGIN;
SELECT hours_allocated AS h FROM engagement_staff WHERE $ROW $lock \gset
\echo \`date +%T.%3N\` [A] read :h, now thinking for 2 seconds
SELECT pg_sleep(2) \g /dev/null
UPDATE engagement_staff SET hours_allocated = :h + 10 WHERE $ROW;
\echo \`date +%T.%3N\` [A] wrote :h + 10
COMMIT;
\echo \`date +%T.%3N\` [A] committed
SQL
    sleep 0.5
    session <<SQL &
BEGIN;
\echo \`date +%T.%3N\` [B] reading ...
SELECT hours_allocated AS h FROM engagement_staff WHERE $ROW $lock \gset
\echo \`date +%T.%3N\` [B] read :h
UPDATE engagement_staff SET hours_allocated = :h + 5 WHERE $ROW;
\echo \`date +%T.%3N\` [B] wrote :h + 5
COMMIT;
\echo \`date +%T.%3N\` [B] committed
SQL
    wait
    show
}

echo "Target row: engagement $E, consultant $C"
echo
echo "=== Run 1: no lock (lost update) ==="
run_demo ""
echo
echo "=== Run 2: SELECT ... FOR UPDATE (B waits for A) ==="
run_demo "FOR UPDATE"
# restore the seed value
value "UPDATE engagement_staff SET hours_allocated = $ORIG WHERE $ROW" > /dev/null
}

main 2>&1 | tee "$LOG"
