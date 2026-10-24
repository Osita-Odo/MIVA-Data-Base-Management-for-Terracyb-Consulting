#!/usr/bin/env bash
# =====================================================================
# Scenario 5: DEADLOCK DETECTION
# Two analysts update the same two findings in opposite order.
# PostgreSQL detects the cycle after deadlock_timeout (1 s by default),
# aborts one transaction and lets the other finish.
# Prevention: always lock rows in the same order (e.g. ORDER BY finding_id).
# =====================================================================
source "$(dirname "$0")/common.sh"
LOG="$OUT_DIR/05_deadlock.log"
main () {

F1=$(value "SELECT min(finding_id) FROM finding WHERE status = 'open'")
F2=$(value "SELECT min(finding_id) FROM finding WHERE status = 'open' AND finding_id > $F1")
echo "Findings used: $F1 and $F2"
echo

session <<SQL &
BEGIN;
UPDATE finding SET status = 'in_progress' WHERE finding_id = $F1;
\echo \`date +%T.%3N\` [A] locked finding $F1
SELECT pg_sleep(1) \g /dev/null
\echo \`date +%T.%3N\` [A] now requesting finding $F2 ...
UPDATE finding SET status = 'in_progress' WHERE finding_id = $F2;
\if :ERROR
\echo \`date +%T.%3N\` [A] chosen as deadlock victim, its transaction is rolled back
\else
\echo \`date +%T.%3N\` [A] got finding $F2
\endif
COMMIT;
\echo \`date +%T.%3N\` [A] finished
SQL
sleep 0.3
session <<SQL &
BEGIN;
UPDATE finding SET status = 'in_progress' WHERE finding_id = $F2;
\echo \`date +%T.%3N\` [B] locked finding $F2
SELECT pg_sleep(1) \g /dev/null
\echo \`date +%T.%3N\` [B] now requesting finding $F1 ...
UPDATE finding SET status = 'in_progress' WHERE finding_id = $F1;
\if :ERROR
\echo \`date +%T.%3N\` [B] chosen as deadlock victim, its transaction is rolled back
\else
\echo \`date +%T.%3N\` [B] got finding $F1
\endif
COMMIT;
\echo \`date +%T.%3N\` [B] finished
SQL
wait

echo
echo "Result (only the surviving transaction's change is kept):"
value "SELECT finding_id || ' ' || status FROM finding WHERE finding_id IN ($F1, $F2) ORDER BY finding_id"
# put both findings back to open for the next run
value "UPDATE finding SET status = 'open' WHERE finding_id IN ($F1, $F2)" > /dev/null
}

main 2>&1 | tee "$LOG"
