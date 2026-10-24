-- =====================================================================
-- Q8  Open risk per TerraCyber office and geopolitical zone
-- Business question: which office carries the heaviest remediation
--                    workload, and in which zones are the clients?
-- Features: 6-table join through the state lookup table, GROUP BY
--           with ROLLUP (subtotals per office and a grand total)
-- Optimised by: idx_finding_unresolved_cover (shared with Q4)
-- =====================================================================
SELECT o.office_code,
       st.geopolitical_zone,
       count(DISTINCT c.client_id)                       AS clients,
       count(*)                                          AS open_findings,
       count(*) FILTER (WHERE f.cvss_score >= 9.0)       AS critical,
       round(avg(f.cvss_score), 2)                       AS avg_cvss
FROM finding f
JOIN asset a       ON a.asset_id    = f.asset_id
JOIN client_site s ON s.site_id     = a.site_id
JOIN client c      ON c.client_id   = s.client_id
JOIN state st      ON st.state_code = c.state_code          -- client's home state
JOIN office o      ON o.office_id   = st.serving_office_id  -- state -> serving office
WHERE f.status IN ('open', 'in_progress')                    -- unresolved findings only
-- ROLLUP adds a subtotal row per office (zone = NULL) and a grand total
-- row (office and zone = NULL) to the normal groups
GROUP BY ROLLUP (o.office_code, st.geopolitical_zone)
ORDER BY o.office_code NULLS LAST, st.geopolitical_zone NULLS LAST;
