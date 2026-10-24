-- =====================================================================
-- pg-africa (Lagos node) initialisation
-- Holds the findings of clients whose data_residency is 'AFRICA', so
-- that data stays in-region (Nigeria NDPA, Kenya DPA, etc.).
-- The EU node reaches this table through postgres_fdw (geo_sharding.sql).
-- =====================================================================
CREATE TABLE finding_geo_africa (
    finding_id     BIGINT       PRIMARY KEY,
    residency      TEXT         NOT NULL CHECK (residency = 'AFRICA'),
    client_id      INT          NOT NULL,
    engagement_id  INT          NOT NULL,
    asset_id       INT          NOT NULL,
    title          TEXT         NOT NULL,
    cvss_score     NUMERIC(3,1) NOT NULL CHECK (cvss_score BETWEEN 0 AND 10),
    status         TEXT         NOT NULL,
    found_on       DATE         NOT NULL,
    fixed_on       DATE
);
CREATE INDEX idx_africa_client ON finding_geo_africa (client_id);
