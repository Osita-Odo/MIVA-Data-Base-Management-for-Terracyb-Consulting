-- =====================================================================
-- Portfolio 5: partitioning (sharding) findings across Nigerian sites
-- Run on the PRIMARY (Lagos node):
--   docker exec -i pg-lagos psql -U postgres -d ead -f /sql/geo_sharding.sql
--
-- finding_geo is LIST-partitioned on the client's sector:
--   'public'  -> finding_geo_public   FOREIGN table: rows live on pg-abuja
--   'private' -> finding_geo_private  local table on the Lagos node
--   'ngo'     -> finding_geo_ngo      local table on the Lagos node
-- Applications query one logical table; PostgreSQL routes reads and
-- writes to the right node (partition pruning + postgres_fdw).
--
-- Why sector and not region? All three sites are in Nigeria, so the NDPA
-- does not force a regional split. The rules that DO care about where
-- data sits are sector rules: government data (NITDA cloud policy) and,
-- for banks and fintechs, the CBN local-hosting circular. Sector is
-- therefore the business-relevant shard key. See docs/site-selection.md.
-- =====================================================================
\set ON_ERROR_STOP on
-- Defaults for Docker; override with -v abuja_host=... -v abuja_port=...
\if :{?abuja_host}
\else
    \set abuja_host pg-abuja
\endif
\if :{?abuja_port}
\else
    \set abuja_port 5432
\endif
SET search_path TO ead;

-- Safe to rerun: remove objects from a previous run first
DROP TABLE IF EXISTS finding_geo CASCADE;
DROP SERVER IF EXISTS abuja_node CASCADE;

-- 1. Connection from Lagos to the Abuja node
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER abuja_node FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host :'abuja_host', port :'abuja_port', dbname 'ead_abuja');
CREATE USER MAPPING FOR CURRENT_USER SERVER abuja_node
    OPTIONS (user 'postgres', password 'terracyber-demo');   -- demo credentials only

-- 2. Partitioned parent table (partition key = sector)
--    sector and office_code are copied from client and state: a deliberate
--    denormalisation, because a partition key must be a column of the table.
CREATE TABLE finding_geo (
    finding_id     BIGINT       NOT NULL,
    sector         TEXT         NOT NULL,
    client_id      INT          NOT NULL,
    office_code    CHAR(3)      NOT NULL,
    engagement_id  INT          NOT NULL,
    asset_id       INT          NOT NULL,
    title          TEXT         NOT NULL,
    cvss_score     NUMERIC(3,1) NOT NULL,
    status         TEXT         NOT NULL,
    found_on       DATE         NOT NULL,
    fixed_on       DATE
) PARTITION BY LIST (sector);

CREATE TABLE finding_geo_private PARTITION OF finding_geo FOR VALUES IN ('private');
CREATE TABLE finding_geo_ngo     PARTITION OF finding_geo FOR VALUES IN ('ngo');
-- Primary keys are added per partition (a key on the parent would have to
-- include the partition key and cannot cover the foreign partition)
ALTER TABLE finding_geo_private ADD PRIMARY KEY (finding_id);
ALTER TABLE finding_geo_ngo     ADD PRIMARY KEY (finding_id);

-- The public-sector partition is a foreign table: its rows are stored in Abuja
CREATE FOREIGN TABLE finding_geo_public
    PARTITION OF finding_geo FOR VALUES IN ('public')
    SERVER abuja_node
    OPTIONS (schema_name 'public', table_name 'finding_geo_public');

-- 3. Load: one INSERT; PostgreSQL routes each row to its partition or node
TRUNCATE finding_geo_private, finding_geo_ngo;
\echo 'Clearing the remote Abuja table ...'
DELETE FROM finding_geo_public;          -- TRUNCATE is not supported on foreign tables

INSERT INTO finding_geo
SELECT f.finding_id, c.sector, c.client_id, o.office_code, f.engagement_id, f.asset_id,
       f.title, f.cvss_score, f.status, f.found_on, f.fixed_on
FROM finding f
JOIN engagement e ON e.engagement_id = f.engagement_id
JOIN client c     ON c.client_id     = e.client_id
JOIN state st     ON st.state_code   = c.state_code
JOIN office o     ON o.office_id     = st.serving_office_id;

ANALYZE finding_geo_private;
ANALYZE finding_geo_ngo;

-- 4. Evidence
\echo ''
\echo '=== Rows per partition (tableoid shows where each row physically lives) ==='
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM finding_geo GROUP BY 1 ORDER BY 1;

\echo ''
\echo '=== Partition pruning: a private-sector query touches only the local partition ==='
EXPLAIN (COSTS OFF)
SELECT count(*) FROM finding_geo WHERE sector = 'private' AND status = 'open';

\echo ''
\echo '=== A public-sector query is sent to the Abuja node (Foreign Scan + Remote SQL) ==='
EXPLAIN (VERBOSE, COSTS OFF)
SELECT client_id, count(*) FROM finding_geo
WHERE sector = 'public' AND status = 'open' GROUP BY client_id;

\echo ''
\echo '=== A query without the partition key fans out to every node ==='
EXPLAIN (COSTS OFF)
SELECT office_code, count(*) FROM finding_geo WHERE cvss_score >= 9 GROUP BY office_code;

SELECT office_code, sector, count(*) AS critical_findings
FROM finding_geo WHERE cvss_score >= 9 GROUP BY office_code, sector ORDER BY office_code, sector;
