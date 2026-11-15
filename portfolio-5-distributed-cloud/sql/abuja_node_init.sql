-- =====================================================================
-- pg-abuja (Abuja node) initialisation
-- Holds the findings of PUBLIC-SECTOR clients. Rationale (see
-- docs/site-selection.md): NITDA's cloud policy and the proposed National
-- Cloud Technical Document emphasise sovereign hosting of government data;
-- Abuja hosts Galaxy Backbone's Tier III National Shared Services Centre
-- and the regulators (NDPC, NITDA, CBN). The Lagos primary reaches this
-- table through postgres_fdw (geo_sharding.sql).
-- =====================================================================
CREATE TABLE finding_geo_public (
    finding_id     BIGINT       PRIMARY KEY,
    sector         TEXT         NOT NULL CHECK (sector = 'public'),   -- this node accepts public-sector rows only
    client_id      INT          NOT NULL,
    office_code    CHAR(3)      NOT NULL,          -- TerraCyb office serving the client
    engagement_id  INT          NOT NULL,
    asset_id       INT          NOT NULL,
    title          TEXT         NOT NULL,
    cvss_score     NUMERIC(3,1) NOT NULL CHECK (cvss_score BETWEEN 0 AND 10),
    status         TEXT         NOT NULL,
    found_on       DATE         NOT NULL,
    fixed_on       DATE
);
CREATE INDEX idx_public_client ON finding_geo_public (client_id);
