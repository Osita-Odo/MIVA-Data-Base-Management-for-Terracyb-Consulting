-- =====================================================================
-- Portfolio 1: constraint tests
-- Every one of the 12 statements below SHOULD FAIL. The error message is the evidence
-- that the schema protects data integrity. Run with:
--   psql -d ead -f test_constraints.sql 2>&1 | tee constraint-test-output.txt
-- =====================================================================
SET search_path TO ead;
-- Keep going after each error: every statement is meant to fail
\set ON_ERROR_STOP off
\echo '--- T1 PRIMARY KEY: duplicate service_id'
-- service_id 1 already exists -> violates service_line_pkey
INSERT INTO service_line (service_id, name) VALUES (1, 'Duplicate service');

\echo '--- T2 UNIQUE: duplicate consultant email'
-- consultant1's email is already taken -> violates consultant_email_key
INSERT INTO consultant (office_id, full_name, email, role, hire_date, hourly_rate_ngn)
VALUES (1, 'Test User', 'consultant1@terracyb.example', 'analyst', DATE '2026-01-01', 48000);

\echo '--- T3 FOREIGN KEY: engagement for a client that does not exist'
-- client 9999 does not exist -> violates engagement_client_id_fkey
INSERT INTO engagement (client_id, service_id, lead_consultant_id, title, start_date, status, budget_ngn)
VALUES (9999, 1, 4, 'Ghost engagement', DATE '2026-01-01', 'planned', 1000);

\echo '--- T4 CHECK: CVSS score above 10'
-- CVSS is defined on a 0-10 scale -> violates finding_cvss_score_check
INSERT INTO finding (engagement_id, asset_id, title, cvss_score, status, found_on)
SELECT f.engagement_id, f.asset_id, 'Bad score', 11.5, 'open', CURRENT_DATE FROM finding f LIMIT 1;

\echo '--- T5 CHECK: engagement ends before it starts'
-- end_date before start_date -> violates ck_engagement_dates
INSERT INTO engagement (client_id, service_id, lead_consultant_id, title, start_date, end_date, status, budget_ngn)
VALUES (1, 1, 4, 'Backwards dates', DATE '2026-05-01', DATE '2026-04-01', 'planned', 1000);

\echo '--- T6 CHECK: status fixed without a fixed_on date'
-- status 'fixed' requires fixed_on -> violates ck_finding_fixed
INSERT INTO finding (engagement_id, asset_id, title, cvss_score, status, found_on)
SELECT f.engagement_id, f.asset_id, 'Fixed but no date', 5.0, 'fixed', CURRENT_DATE FROM finding f LIMIT 1;

\echo '--- T7 CHECK: invalid sector value'
-- 'charity' is not one of ngo / public / private -> violates client_sector_check
INSERT INTO client (name, sector, state_code) VALUES ('Test Org', 'charity', 'LA');

\echo '--- T8 CHECK: malformed CVE identifier'
-- 'CVE-21-1' does not match ^CVE-[0-9]{4}-[0-9]{4,}$ -> violates finding_cve_id_check
INSERT INTO finding (engagement_id, asset_id, title, cve_id, cvss_score, status, found_on)
SELECT f.engagement_id, f.asset_id, 'Bad CVE', 'CVE-21-1', 5.0, 'open', CURRENT_DATE FROM finding f LIMIT 1;

\echo '--- T9 TRIGGER: asset belongs to a different client than the engagement'
-- Pairs an advisory engagement with an asset of ANOTHER client.
-- No CHECK can see two tables, so trigger trg_finding_asset_client rejects it.
INSERT INTO finding (engagement_id, asset_id, title, cvss_score, status, found_on)
SELECT e.engagement_id, a.asset_id, 'Wrong client asset', 5.0, 'open', CURRENT_DATE
FROM engagement e
JOIN asset a ON a.site_id IN (SELECT site_id FROM client_site WHERE client_id <> e.client_id)
WHERE e.service_id = 2
LIMIT 1;

\echo '--- T10 TRIGGER: payment larger than the invoice'
-- Invoice 1 is already fully paid; 1 naira more would overpay it.
-- Rejected by trigger trg_payment_within_invoice.
INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
SELECT invoice_id, amount_ngn + 1, CURRENT_DATE, 'card' FROM invoice ORDER BY invoice_id LIMIT 1;

\echo '--- T11 GENERATED column: severity cannot be written directly'
-- severity is GENERATED ALWAYS from cvss_score, so it can never be set by hand
UPDATE finding SET severity = 'low' WHERE finding_id = 1;

\echo '--- T12 FOREIGN KEY: client in a state code that does not exist'
-- 'XX' is not one of the 36 states + FCT in the state table -> violates client_state_code_fkey
INSERT INTO client (name, sector, state_code) VALUES ('Nowhere Ltd', 'private', 'XX');

\echo '--- Done. Expect 12 ERROR lines above and no rows inserted.'
