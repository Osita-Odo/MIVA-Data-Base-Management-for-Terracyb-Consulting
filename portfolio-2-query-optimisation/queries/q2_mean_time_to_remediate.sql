-- =====================================================================
-- Q2  Mean time to remediate (MTTR) per service line and quarter
-- Business question: are we getting faster at closing findings, and
--                    does it differ between service lines?
-- Features: JOINs, GROUP BY on an expression, aggregates on date arithmetic
-- Optimised by: materialised view mv_mttr (indexes.sql), read in q2b
-- =====================================================================
SELECT sl.name                                  AS service_line,
       date_trunc('quarter', f.fixed_on)::date  AS quarter,          -- e.g. 2025-04-01 = Q2 2025
       count(*)                                 AS findings_fixed,
       round(avg(f.fixed_on - f.found_on), 1)   AS avg_days_to_fix   -- date - date = whole days
FROM finding f
JOIN engagement e    ON e.engagement_id = f.engagement_id   -- finding -> engagement
JOIN service_line sl ON sl.service_id   = e.service_id      -- engagement -> service line name
WHERE f.status = 'fixed'          -- only fixed findings have a fixed_on date
                                  -- (enforced by CHECK ck_finding_fixed)
GROUP BY sl.name, date_trunc('quarter', f.fixed_on)   -- same expression as in SELECT
ORDER BY sl.name, quarter;
