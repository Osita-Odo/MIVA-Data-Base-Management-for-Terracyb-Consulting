-- =====================================================================
-- Q3  Clients below 70% compliance against ISO/IEC 27001
-- Business question: which clients need a remediation plan first?
-- Features: CTE, conditional aggregation with FILTER, HAVING
-- Optimisation: none added on purpose (small table, see README section 4)
-- =====================================================================
WITH iso AS (
    -- One row per client: how many ISO controls are compliant, out of
    -- how many actually apply to them
    SELECT e.client_id,
           count(*) FILTER (WHERE ca.rating = 'compliant')       AS compliant,
           count(*) FILTER (WHERE ca.rating <> 'not_applicable') AS assessed   -- N/A controls
                                                                               -- are excluded from the base
    FROM control_assessment ca
    JOIN control ct    ON ct.control_id    = ca.control_id
    JOIN framework fw  ON fw.framework_id  = ct.framework_id
    JOIN engagement e  ON e.engagement_id  = ca.engagement_id
    WHERE fw.name = 'ISO/IEC 27001'          -- ignore NDPA and NIST CSF assessments
    GROUP BY e.client_id
    -- HAVING filters groups after aggregation (WHERE cannot see aggregates).
    -- NULLIF avoids a division by zero if every control were N/A.
    HAVING 100.0 * count(*) FILTER (WHERE ca.rating = 'compliant')
           / NULLIF(count(*) FILTER (WHERE ca.rating <> 'not_applicable'), 0) < 70
)
SELECT c.name, c.sector, iso.compliant, iso.assessed,
       round(100.0 * iso.compliant / iso.assessed, 1) AS compliance_pct   -- 100.0 forces decimal division
FROM iso
JOIN client c ON c.client_id = iso.client_id    -- add the client's name and sector
ORDER BY compliance_pct;                        -- weakest client first
