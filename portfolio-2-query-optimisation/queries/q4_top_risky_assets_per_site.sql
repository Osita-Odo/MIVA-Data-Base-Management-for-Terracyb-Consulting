-- =====================================================================
-- Q4  Top 5 riskiest assets at each client site
-- Business question: where should a site's IT team start patching?
-- Risk score = sum of the CVSS scores of the asset's unresolved findings.
-- Features: two CTEs, aggregation, window function RANK() OVER (PARTITION BY)
-- Optimised by: idx_finding_unresolved_cover (covering partial index)
-- =====================================================================
WITH asset_risk AS (
    -- Step 1: one row per asset with its open-finding count and risk score
    SELECT a.site_id, a.asset_id, a.hostname,
           count(*)          AS open_findings,
           sum(f.cvss_score) AS total_cvss
    FROM finding f
    JOIN asset a ON a.asset_id = f.asset_id
    WHERE f.status IN ('open', 'in_progress')     -- fixed and accepted risks do not count
    GROUP BY a.site_id, a.asset_id, a.hostname
), ranked AS (
    -- Step 2: rank assets inside each site. PARTITION BY restarts the
    -- ranking for every site; unlike GROUP BY it keeps every row.
    -- RANK gives equal scores the same position (ties are kept).
    SELECT ar.*,
           RANK() OVER (PARTITION BY ar.site_id ORDER BY ar.total_cvss DESC) AS risk_rank
    FROM asset_risk ar
)
-- Step 3: keep the top 5 per site and add readable client and site names
SELECT c.name AS client_name, s.site_name, r.hostname,
       r.open_findings, r.total_cvss, r.risk_rank
FROM ranked r
JOIN client_site s ON s.site_id   = r.site_id
JOIN client c      ON c.client_id = s.client_id
WHERE r.risk_rank <= 5          -- a window result can only be filtered in an outer query
ORDER BY c.name, s.site_name, r.risk_rank;
