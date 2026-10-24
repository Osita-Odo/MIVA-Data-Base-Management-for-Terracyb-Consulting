-- =====================================================================
-- Q7  Where is Log4Shell (CVE-2021-44228) still unfixed?
-- Business question: an urgent advisory arrives; which client hosts are
--                    still exposed?
-- Features: highly selective equality filter, the classic B-tree case
-- Optimised by: idx_finding_cve (partial index, rows with a CVE only)
-- =====================================================================
SELECT f.finding_id, c.name AS client_name, a.hostname, f.status, f.found_on
FROM finding f
JOIN asset a       ON a.asset_id  = f.asset_id    -- which host
JOIN client_site s ON s.site_id   = a.site_id     -- which site
JOIN client c      ON c.client_id = s.client_id   -- which client to notify
WHERE f.cve_id = 'CVE-2021-44228'                 -- matches a small share of the table
  AND f.status <> 'fixed'                         -- open, in progress or risk-accepted
ORDER BY f.found_on;
