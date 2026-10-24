-- =====================================================================
-- Portfolio 2: remove every optimisation from indexes.sql
-- run_benchmark.sh runs this first so the "before" timings measure the
-- schema from Portfolio 1 only. IF EXISTS makes it safe to rerun.
-- =====================================================================
SET search_path TO ead;
DROP INDEX IF EXISTS idx_finding_open_critical;      -- Q1 partial index
DROP INDEX IF EXISTS idx_finding_unresolved_cover;   -- Q4 covering index
DROP INDEX IF EXISTS idx_finding_title_fts;          -- Q6b GIN full-text index
DROP INDEX IF EXISTS idx_finding_cve;                -- Q7 partial index
DROP MATERIALIZED VIEW IF EXISTS mv_mttr;            -- Q2 precomputed result (drops idx_mv_mttr too)
-- Refresh statistics so the planner does not plan with stale numbers
VACUUM ANALYZE finding;
