-- =====================================================================
-- Portfolio 2: join algorithm experiment on Q5
-- Forces the planner away from its first choice to compare join methods.
-- Run: psql -d ead -f join_strategies.sql > plans/join-strategies.txt
-- The enable_* settings only last for this session.
-- =====================================================================
SET search_path TO ead;

-- The same query is planned three times. Only the join method changes,
-- so differences in cost and time come from the join algorithm alone.
\echo '=== 1. Planner default ==='
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT e.engagement_id, sum(es.hours_allocated * co.hourly_rate_ngn) AS planned_cost
FROM engagement e
LEFT JOIN engagement_staff es ON es.engagement_id = e.engagement_id
LEFT JOIN consultant co       ON co.consultant_id = es.consultant_id
GROUP BY e.engagement_id;

\echo '=== 2. Hash joins disabled ==='
-- enable_* does not forbid a method; it makes it look very expensive,
-- so the planner picks the next best one.
SET enable_hashjoin = off;
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT e.engagement_id, sum(es.hours_allocated * co.hourly_rate_ngn) AS planned_cost
FROM engagement e
LEFT JOIN engagement_staff es ON es.engagement_id = e.engagement_id
LEFT JOIN consultant co       ON co.consultant_id = es.consultant_id
GROUP BY e.engagement_id;

\echo '=== 3. Hash and merge joins disabled (nested loops only) ==='
SET enable_mergejoin = off;
EXPLAIN (ANALYZE, BUFFERS, COSTS)
SELECT e.engagement_id, sum(es.hours_allocated * co.hourly_rate_ngn) AS planned_cost
FROM engagement e
LEFT JOIN engagement_staff es ON es.engagement_id = e.engagement_id
LEFT JOIN consultant co       ON co.consultant_id = es.consultant_id
GROUP BY e.engagement_id;

RESET enable_hashjoin;
RESET enable_mergejoin;

-- Restore the defaults so later statements in this session are unaffected
\echo '=== 4. Estimate vs actual on a skewed filter (planner statistics) ==='
EXPLAIN (ANALYZE)
-- The planner assumes status and severity are independent and multiplies
-- their selectivities. Compare its rows= estimate with the actual rows.
SELECT count(*) FROM finding WHERE status = 'accepted' AND severity = 'critical';

-- Optional fix to try and discuss: extended statistics tell the planner
-- that the two columns are related.
--   CREATE STATISTICS st_finding_status_sev (dependencies, mcv) ON status, severity FROM finding;
--   ANALYZE finding;
