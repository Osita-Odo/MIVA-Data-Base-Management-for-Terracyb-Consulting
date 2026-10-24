-- =====================================================================
-- Scenario 1: COMMIT. Close a finding and record it atomically.
-- One transaction changes the finding; the audit trigger writes the
-- audit_log row inside the SAME transaction. Both persist, or neither.
-- Run: psql -d ead -f 01_commit_close_finding.sql
-- =====================================================================
SET search_path TO ead;
\set ON_ERROR_STOP on

-- Pick the oldest open finding as the target
SELECT finding_id AS fid FROM finding WHERE status = 'open' ORDER BY found_on, finding_id LIMIT 1 \gset
\echo '>>> Target finding:' :fid

\echo '>>> Before:'
SELECT finding_id, status, found_on, fixed_on FROM finding WHERE finding_id = :fid;
SELECT count(*) AS audit_rows_for_finding FROM audit_log WHERE table_name = 'finding' AND record_id = :fid;

BEGIN;
    UPDATE finding
    SET status = 'fixed', fixed_on = CURRENT_DATE
    WHERE finding_id = :fid;

    \echo '>>> Inside the transaction, before COMMIT (this session sees the change):'
    SELECT finding_id, status, fixed_on FROM finding WHERE finding_id = :fid;
COMMIT;

\echo '>>> After COMMIT: change is durable and audited'
SELECT finding_id, status, found_on, fixed_on FROM finding WHERE finding_id = :fid;
SELECT log_id, action, old_data ->> 'status' AS old_status, new_data ->> 'status' AS new_status,
       changed_by, changed_at
FROM audit_log WHERE table_name = 'finding' AND record_id = :fid ORDER BY log_id;
