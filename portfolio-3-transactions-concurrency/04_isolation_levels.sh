#!/usr/bin/env bash
# =====================================================================
# Scenario 4: ISOLATION LEVELS
# Part 1: a compliance report reads the same figure twice while an
#         analyst updates ratings.
#         READ COMMITTED  -> non-repeatable read (the two figures differ)
#         REPEATABLE READ -> stable snapshot (the two figures match)
# Part 2: write skew. Rule: an engagement must keep at least one analyst.
#         Two managers each remove a different analyst after checking
#         that "another analyst remains".
#         REPEATABLE READ -> both succeed, zero analysts left (anomaly)
#         SERIALIZABLE    -> one transaction fails with SQLSTATE 40001
# Why SERIALIZABLE (D47): the managers delete DIFFERENT rows, so row locks
# never conflict; only serializable isolation detects this anomaly.
# =====================================================================
source "$(dirname "$0")/common.sh"
LOG="$OUT_DIR/04_isolation_levels.log"
main () {

# ---------- Part 1 setup ----------
E=$(value "SELECT engagement_id FROM control_assessment GROUP BY engagement_id ORDER BY engagement_id LIMIT 1")
value "DROP TABLE IF EXISTS demo_rating_backup; CREATE TABLE demo_rating_backup AS SELECT assessment_id, rating FROM control_assessment WHERE engagement_id = $E" > /dev/null
restore_ratings () { value "UPDATE control_assessment ca SET rating = b.rating FROM demo_rating_backup b WHERE b.assessment_id = ca.assessment_id" > /dev/null; }

report_vs_update () {   # $1 = isolation level
    restore_ratings
    session <<SQL &
BEGIN ISOLATION LEVEL $1;
SELECT count(*) AS n FROM control_assessment WHERE engagement_id = $E AND rating = 'compliant' \gset
\echo \`date +%T.%3N\` [Report] first read: :n compliant controls
SELECT pg_sleep(2) \g /dev/null
SELECT count(*) AS n FROM control_assessment WHERE engagement_id = $E AND rating = 'compliant' \gset
\echo \`date +%T.%3N\` [Report] second read, same transaction: :n compliant controls
COMMIT;
SQL
    sleep 0.7
    session <<SQL &
UPDATE control_assessment SET rating = 'compliant'
WHERE engagement_id = $E AND rating = 'partial';
\echo \`date +%T.%3N\` [Analyst] upgraded all partial ratings to compliant and committed
SQL
    wait
}

echo "Engagement used for Part 1: $E"
echo
echo "=== Part 1a: READ COMMITTED ==="
report_vs_update "READ COMMITTED"
echo
echo "=== Part 1b: REPEATABLE READ ==="
report_vs_update "REPEATABLE READ"
restore_ratings
value "DROP TABLE demo_rating_backup" > /dev/null

# ---------- Part 2 setup ----------
E2=$(value "SELECT engagement_id FROM engagement_staff WHERE role_on_engagement = 'Analyst' GROUP BY engagement_id HAVING count(*) = 2 ORDER BY engagement_id LIMIT 1")
A1=$(value "SELECT min(consultant_id) FROM engagement_staff WHERE engagement_id = $E2 AND role_on_engagement = 'Analyst'")
A2=$(value "SELECT max(consultant_id) FROM engagement_staff WHERE engagement_id = $E2 AND role_on_engagement = 'Analyst'")
value "DROP TABLE IF EXISTS demo_staff_backup; CREATE TABLE demo_staff_backup AS SELECT * FROM engagement_staff WHERE engagement_id = $E2" > /dev/null
restore_staff () { value "DELETE FROM engagement_staff WHERE engagement_id = $E2; INSERT INTO engagement_staff SELECT * FROM demo_staff_backup" > /dev/null; }
analysts () { value "SELECT count(*) FROM engagement_staff WHERE engagement_id = $E2 AND role_on_engagement = 'Analyst'"; }

remove_if_another_remains () {   # $1 = label, $2 = consultant to remove, $3 = isolation level
    session <<SQL
BEGIN ISOLATION LEVEL $3;
SELECT count(*) AS n, count(*) > 1 AS ok FROM engagement_staff
WHERE engagement_id = $E2 AND role_on_engagement = 'Analyst' \gset
\echo \`date +%T.%3N\` [$1] sees :n analysts, safe to remove one: :ok
SELECT pg_sleep(1.5) \g /dev/null
\if :ok
DELETE FROM engagement_staff WHERE engagement_id = $E2 AND consultant_id = $2;
\if :ERROR
\echo \`date +%T.%3N\` [$1] DELETE failed: serialisation failure, transaction rolled back
\else
\echo \`date +%T.%3N\` [$1] removed consultant $2
\endif
\endif
COMMIT;
\if :ERROR
\echo \`date +%T.%3N\` [$1] COMMIT failed: serialisation failure, transaction rolled back
\else
\echo \`date +%T.%3N\` [$1] transaction ended
\endif
SQL
}

write_skew () {   # $1 = isolation level
    restore_staff
    echo "    Analysts before: $(analysts)"
    remove_if_another_remains "Manager A" "$A1" "$1" &
    sleep 0.3
    remove_if_another_remains "Manager B" "$A2" "$1" &
    wait
    echo "    Analysts after: $(analysts)  (the rule requires at least 1)"
}

echo
echo "Engagement used for Part 2: $E2 (analysts $A1 and $A2)"
echo
echo "=== Part 2a: REPEATABLE READ (write skew is possible) ==="
write_skew "REPEATABLE READ"
echo
echo "=== Part 2b: SERIALIZABLE (write skew is prevented) ==="
write_skew "SERIALIZABLE"
restore_staff
value "DROP TABLE demo_staff_backup" > /dev/null
}

main 2>&1 | tee "$LOG"
