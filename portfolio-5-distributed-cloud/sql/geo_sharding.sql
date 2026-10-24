-- =====================================================================
-- Portfolio 5: geo-partitioning (sharding) of findings by data residency
-- Run on the PRIMARY (Bonn / EU node):
--   docker exec -i pg-primary psql -U postgres -d ead -f /sql/geo_sharding.sql
--
-- finding_geo is LIST-partitioned on residency:
--   'EU'     -> finding_geo_eu      local table on the EU node
--   'OTHER'  -> finding_geo_other   local table on the EU node
--   'AFRICA' -> finding_geo_africa  FOREIGN table: rows live on pg-africa
-- Applications query one logical table; PostgreSQL routes reads and
-- writes to the right node (partition pruning + postgres_fdw).
-- =====================================================================
\set ON_ERROR_STOP on
\if :{?africa_host}
\else
    \set africa_host pg-africa
\endif
\if :{?africa_port}
\else
    \set africa_port 5432
\endif
SET search_path TO ead;

DROP TABLE IF EXISTS finding_geo CASCADE;
DROP SERVER IF EXISTS africa_node CASCADE;

-- 1. Connection to the Lagos node
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER africa_node FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host :'africa_host', port :'africa_port', dbname 'ead_africa');
CREATE USER MAPPING FOR CURRENT_USER SERVER africa_node
    OPTIONS (user 'postgres', password 'terracyber-demo');

-- 2. Partitioned parent table (partition key = residency)
--    residency is copied from client.data_residency: a deliberate
--    denormalisation, because a partition key must be a column of the table.
CREATE TABLE finding_geo (
    finding_id     BIGINT       NOT NULL,
    residency      TEXT         NOT NULL,
    client_id      INT          NOT NULL,
    engagement_id  INT          NOT NULL,
    asset_id       INT          NOT NULL,
    title          TEXT         NOT NULL,
    cvss_score     NUMERIC(3,1) NOT NULL,
    status         TEXT         NOT NULL,
    found_on       DATE         NOT NULL,
    fixed_on       DATE
) PARTITION BY LIST (residency);

CREATE TABLE finding_geo_eu    PARTITION OF finding_geo FOR VALUES IN ('EU');
CREATE TABLE finding_geo_other PARTITION OF finding_geo FOR VALUES IN ('OTHER');
ALTER TABLE finding_geo_eu    ADD PRIMARY KEY (finding_id);
ALTER TABLE finding_geo_other ADD PRIMARY KEY (finding_id);

CREATE FOREIGN TABLE finding_geo_africa
    PARTITION OF finding_geo FOR VALUES IN ('AFRICA')
    SERVER africa_node
    OPTIONS (schema_name 'public', table_name 'finding_geo_africa');

-- 3. Load: one INSERT, PostgreSQL routes each row to its partition or node
TRUNCATE finding_geo_eu, finding_geo_other;
\echo 'Clearing the remote Africa table ...'
DELETE FROM finding_geo_africa;

INSERT INTO finding_geo
SELECT f.finding_id, c.data_residency, c.client_id, f.engagement_id, f.asset_id,
       f.title, f.cvss_score, f.status, f.found_on, f.fixed_on
FROM finding f
JOIN engagement e ON e.engagement_id = f.engagement_id
JOIN client c     ON c.client_id     = e.client_id;

ANALYZE finding_geo_eu;
ANALYZE finding_geo_other;

-- 4. Evidence
\echo ''
\echo '=== Rows per partition (tableoid shows where each row physically lives) ==='
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM finding_geo GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== Partition pruning: an EU query touches only the local EU partition ==='
EXPLAIN (COSTS OFF)
SELECT count(*) FROM finding_geo WHERE residency = 'EU' AND status = 'open';

\echo ''
\echo '=== An AFRICA query is sent to the Lagos node (Foreign Scan + Remote SQL) ==='
EXPLAIN (VERBOSE, COSTS OFF)
SELECT client_id, count(*) FROM finding_geo
WHERE residency = 'AFRICA' AND status = 'open' GROUP BY client_id;

\echo ''
\echo '=== A query without the partition key fans out to every node ==='
EXPLAIN (COSTS OFF)
SELECT residency, count(*) FROM finding_geo WHERE cvss_score >= 9 GROUP BY residency;

SELECT residency, count(*) AS critical_findings
FROM finding_geo WHERE cvss_score >= 9 GROUP BY residency ORDER BY residency;
