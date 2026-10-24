-- =====================================================================
-- Q1  Triage queue: open critical findings, oldest first
-- Business question: which critical vulnerabilities have waited longest
--                    for remediation across all clients?
-- Features: query over a view (4-table join), filter, ORDER BY + LIMIT
-- Optimised by: idx_finding_open_critical (partial index, indexes.sql)
-- =====================================================================
SELECT client_name, site_name, hostname, finding_id, title,
       cvss_score, found_on, days_open
FROM v_open_findings            -- view from schema.sql: joins finding, asset, client_site, client
                                -- and keeps only open or in_progress findings
WHERE severity = 'critical'     -- severity is a generated column (CVSS >= 9.0)
ORDER BY found_on               -- oldest first = longest exposure first
LIMIT 50;                       -- a triage list, not a full report; lets an
                                -- ordered index stop after 50 rows
