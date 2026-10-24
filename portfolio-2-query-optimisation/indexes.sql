-- =====================================================================
-- Portfolio 2: optimisation objects, one per query problem
-- =====================================================================
SET search_path TO ead;

-- Q1 (D35): partial index that holds only open or in-progress critical findings,
-- already sorted by found_on. The planner can read the first 50 entries
-- in order and stop, instead of scanning and sorting the whole table.
CREATE INDEX IF NOT EXISTS idx_finding_open_critical
    ON finding (found_on)
    WHERE severity = 'critical' AND status IN ('open', 'in_progress');

-- Q2 (D36): the query aggregates most of the table, so no index can help much.
-- Precompute it in a materialised view and refresh it after each load.
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_mttr AS
SELECT sl.name                                  AS service_line,
       date_trunc('quarter', f.fixed_on)::date  AS quarter,
       count(*)                                 AS findings_fixed,
       round(avg(f.fixed_on - f.found_on), 1)   AS avg_days_to_fix
FROM finding f
JOIN engagement e    ON e.engagement_id = f.engagement_id
JOIN service_line sl ON sl.service_id   = e.service_id
WHERE f.status = 'fixed'
GROUP BY sl.name, date_trunc('quarter', f.fixed_on);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_mttr ON mv_mttr (service_line, quarter);

-- Q3 (D37): control_assessment already has a UNIQUE (engagement_id, control_id)
-- index from Portfolio 1. No new index: the table is small (about 2,200
-- rows) and the query reads most of it. Kept as the "index does not help" case.

-- Q4 (D38): covering index. Only unresolved findings are needed, and only the
-- asset_id and cvss_score columns. INCLUDE lets an index-only scan answer it.
CREATE INDEX IF NOT EXISTS idx_finding_unresolved_cover
    ON finding (asset_id) INCLUDE (cvss_score)
    WHERE status IN ('open', 'in_progress');

-- Q6b (D39): GIN index on the full-text vector of the title. Chosen over a
-- trigram index because full-text search also matches word forms.
CREATE INDEX IF NOT EXISTS idx_finding_title_fts
    ON finding USING gin (to_tsvector('english', title));

-- Q7 (D40): partial B-tree index on CVE id. Most findings have no CVE, so the
-- index skips those rows and stays small.
CREATE INDEX IF NOT EXISTS idx_finding_cve
    ON finding (cve_id)
    WHERE cve_id IS NOT NULL;

-- Index-only scans need an up-to-date visibility map, and the planner needs statistics.
VACUUM ANALYZE finding;
