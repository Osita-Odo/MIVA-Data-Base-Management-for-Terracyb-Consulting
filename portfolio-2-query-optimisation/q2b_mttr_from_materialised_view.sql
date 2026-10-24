-- =====================================================================
-- Q2b  Same result as Q2, read from the materialised view mv_mttr
-- Run after indexes.sql has created the view.
-- A materialised view stores the query result on disk, so this reads a
-- few dozen precomputed rows instead of aggregating about 50,000 findings.
-- Trade-off: the data is only as fresh as the last
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_mttr;
-- (CONCURRENTLY needs the unique index idx_mv_mttr and does not block readers.)
-- =====================================================================
SELECT service_line, quarter, findings_fixed, avg_days_to_fix
FROM mv_mttr
ORDER BY service_line, quarter;
