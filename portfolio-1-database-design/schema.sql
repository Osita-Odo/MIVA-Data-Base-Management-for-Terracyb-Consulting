-- =====================================================================
-- TerraCyb Consulting: Engagement and Assurance Database (EAD)
-- Portfolio 1: relational schema (PostgreSQL 16)
-- Run:  psql -d ead -f schema.sql
--
-- DESIGN CONVENTIONS AND THE REASON FOR EACH (decision IDs refer to
-- docs/design-decisions.md)
--   * One schema, "ead" (D10): keeps the project apart from other objects
--     in the database and lets the whole design be dropped and rebuilt in
--     one statement, so every test run starts from the same state.
--   * Surrogate integer keys (SERIAL) for business entities (D11): names
--     and titles change; an integer key never does, and integer joins are
--     fast. Exceptions: state (natural code), service_line (3 fixed rows),
--     and the two junction tables (composite keys).
--   * BIGSERIAL for finding and audit_log only (D12): these are the tables
--     that grow without limit; the others stay small.
--   * TEXT + CHECK instead of ENUM types for status-like columns (D13):
--     a CHECK can be changed with one ALTER TABLE, the allowed values are
--     visible next to the column, and the error names the broken rule.
--   * NUMERIC for money and CVSS scores (D14): exact decimals. Floating
--     point (REAL/DOUBLE) cannot store values such as 0.1 exactly, which
--     is unacceptable for invoices and payments.
--   * Every foreign key is NOT NULL unless the relationship is optional,
--     and foreign key columns are indexed (D25): PostgreSQL does not
--     index them automatically, and joins and cascades need them.
--   * ON DELETE CASCADE only for rows that cannot exist without their
--     parent (sites, assets, staffing, assessments, sessions, attendance);
--     the default RESTRICT everywhere else (D19): findings, invoices and
--     payments are evidence and financial records and must never vanish
--     because a parent row was deleted by mistake.
-- =====================================================================

DROP SCHEMA IF EXISTS ead CASCADE;
CREATE SCHEMA ead;
SET search_path TO ead;

-- ---------------------------------------------------------------------
-- 1. Geography and organisation: states, offices and consultants
--    TerraCyb operates from three Nigerian sites (Lagos, Abuja,
--    Port Harcourt). See docs/site-selection.md for why these were chosen.
-- ---------------------------------------------------------------------
CREATE TABLE office (
    office_id     SERIAL PRIMARY KEY,
    -- IATA city code (LOS, ABV, PHC): short, already standard, and used as
    -- the readable office label in reports and in Portfolio 5 partitions
    office_code   CHAR(3)     NOT NULL UNIQUE,
    office_name   TEXT        NOT NULL,
    city          TEXT        NOT NULL UNIQUE,
    site_role     TEXT        NOT NULL CHECK (site_role IN ('headquarters', 'regional')),
    -- Role of the office's data centre in the distributed design (Portfolio 5)
    db_role       TEXT        NOT NULL CHECK (db_role IN ('primary', 'standby', 'public_sector_shard'))
);

-- Nigeria's 36 states and the FCT. Zone and serving office depend on the
-- STATE, not on the client, so they live here (3NF: no transitive dependency
-- client -> state -> zone inside the client table).
CREATE TABLE state (
    -- Natural key (e.g. LA, FC, RI): the 37 codes are stable and meaningful,
    -- so a surrogate integer would add a join without adding anything
    state_code         CHAR(2)  PRIMARY KEY,
    state_name         TEXT     NOT NULL UNIQUE,
    geopolitical_zone  TEXT     NOT NULL CHECK (geopolitical_zone IN
                           ('North Central', 'North East', 'North West',
                            'South East', 'South South', 'South West')),
    serving_office_id  INT      NOT NULL REFERENCES office (office_id)
);

CREATE TABLE consultant (
    consultant_id    SERIAL PRIMARY KEY,
    office_id        INT          NOT NULL REFERENCES office (office_id),
    full_name        TEXT         NOT NULL,
    email            TEXT         NOT NULL UNIQUE,
    role             TEXT         NOT NULL CHECK (role IN ('analyst', 'lead', 'manager', 'trainer')),
    hire_date        DATE         NOT NULL,
    hourly_rate_ngn  NUMERIC(10,2) NOT NULL CHECK (hourly_rate_ngn > 0)   -- naira per hour
);

-- ---------------------------------------------------------------------
-- 2. Clients and their sites
-- ---------------------------------------------------------------------
CREATE TABLE client (
    client_id    SERIAL PRIMARY KEY,
    name         TEXT    NOT NULL UNIQUE,
    sector       TEXT    NOT NULL CHECK (sector IN ('ngo', 'public', 'private')),
    -- State of the client's head office; it decides which TerraCyb office
    -- serves the client (state.serving_office_id)
    state_code   CHAR(2) NOT NULL REFERENCES state (state_code),
    created_at   DATE    NOT NULL DEFAULT CURRENT_DATE
);

-- A client can have several sites in different states (head office, data
-- centre, field office), so sites are a separate table rather than
-- address columns repeated in client (1NF: no repeating groups).
CREATE TABLE client_site (
    site_id     SERIAL PRIMARY KEY,
    client_id   INT     NOT NULL REFERENCES client (client_id) ON DELETE CASCADE,
    site_name   TEXT    NOT NULL,
    city        TEXT    NOT NULL,
    state_code  CHAR(2) NOT NULL REFERENCES state (state_code),   -- a site can be in another state
    CONSTRAINT uq_site_name UNIQUE (client_id, site_name)
);

-- ---------------------------------------------------------------------
-- 3. Services and engagements
-- ---------------------------------------------------------------------
-- Small fixed reference table: the ids are assigned by hand (1-3) rather
-- than by a sequence, so scripts can refer to a service line by a known id.
CREATE TABLE service_line (
    service_id  SMALLINT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE
);

CREATE TABLE engagement (
    engagement_id       SERIAL PRIMARY KEY,
    client_id           INT           NOT NULL REFERENCES client (client_id),
    service_id          SMALLINT      NOT NULL REFERENCES service_line (service_id),
    lead_consultant_id  INT           NOT NULL REFERENCES consultant (consultant_id),
    title               TEXT          NOT NULL,
    start_date          DATE          NOT NULL,
    end_date            DATE,          -- NULL while an engagement is still running
    status              TEXT          NOT NULL CHECK (status IN ('planned', 'active', 'closed', 'cancelled')),
    budget_ngn          NUMERIC(14,2) NOT NULL CHECK (budget_ngn >= 0),
    CONSTRAINT ck_engagement_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Junction table: resolves the many-to-many between consultant and engagement
CREATE TABLE engagement_staff (
    engagement_id       INT          NOT NULL REFERENCES engagement (engagement_id) ON DELETE CASCADE,
    consultant_id       INT          NOT NULL REFERENCES consultant (consultant_id),
    role_on_engagement  TEXT         NOT NULL,
    hours_allocated     NUMERIC(6,1) NOT NULL CHECK (hours_allocated >= 0),
    -- Composite key: a consultant appears at most once per engagement, and
    -- no extra surrogate id is needed to identify a row
    PRIMARY KEY (engagement_id, consultant_id)
);

-- ---------------------------------------------------------------------
-- 4. Assets and vulnerability findings
-- ---------------------------------------------------------------------
CREATE TABLE asset (
    asset_id         SERIAL PRIMARY KEY,
    site_id          INT     NOT NULL REFERENCES client_site (site_id) ON DELETE CASCADE,
    hostname         TEXT    NOT NULL,
    -- INET rather than TEXT: PostgreSQL validates the address and supports
    -- network operators (e.g. ip_address << '10.1.0.0/16') for scoping scans.
    -- NULL allowed because SaaS applications may have no fixed address.
    ip_address       INET,
    asset_type       TEXT    NOT NULL CHECK (asset_type IN ('server', 'workstation', 'network', 'cloud', 'application')),
    criticality      TEXT    NOT NULL CHECK (criticality IN ('low', 'medium', 'high', 'critical')),
    internet_facing  BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_asset_host UNIQUE (site_id, hostname)
);

CREATE TABLE finding (
    finding_id     BIGSERIAL PRIMARY KEY,
    engagement_id  INT          NOT NULL REFERENCES engagement (engagement_id),
    asset_id       INT          NOT NULL REFERENCES asset (asset_id),
    title          TEXT         NOT NULL,
    -- NULL for weaknesses without a CVE (e.g. weak password policy);
    -- when present, the pattern rejects malformed identifiers
    cve_id         TEXT         CHECK (cve_id ~ '^CVE-[0-9]{4}-[0-9]{4,}$'),
    cvss_score     NUMERIC(3,1) NOT NULL CHECK (cvss_score BETWEEN 0 AND 10),
    -- Severity is derived from CVSS v3 ranges. A generated column keeps it
    -- consistent with cvss_score, so it is never updated independently (3NF safe).
    severity       TEXT GENERATED ALWAYS AS (
                       CASE
                           WHEN cvss_score >= 9.0 THEN 'critical'
                           WHEN cvss_score >= 7.0 THEN 'high'
                           WHEN cvss_score >= 4.0 THEN 'medium'
                           WHEN cvss_score >  0.0 THEN 'low'
                           ELSE 'none'
                       END) STORED,
    status         TEXT         NOT NULL CHECK (status IN ('open', 'in_progress', 'fixed', 'accepted')),
    found_on       DATE         NOT NULL,
    fixed_on       DATE,
    CONSTRAINT ck_finding_dates CHECK (fixed_on IS NULL OR fixed_on >= found_on),
    -- "fixed" if and only if a fix date exists: stops the MTTR report (Q2)
    -- from counting findings that are fixed but undated, or dated but open
    CONSTRAINT ck_finding_fixed CHECK ((status = 'fixed') = (fixed_on IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- 5. Compliance frameworks, controls and assessments
-- ---------------------------------------------------------------------
CREATE TABLE framework (
    framework_id  SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    version       TEXT NOT NULL,
    CONSTRAINT uq_framework UNIQUE (name, version)
);

-- Controls are stored as rows, not columns, so a new framework or a new
-- framework version is added with INSERTs instead of a schema change.
CREATE TABLE control (
    control_id    SERIAL PRIMARY KEY,
    framework_id  INT  NOT NULL REFERENCES framework (framework_id),
    ref_code      TEXT NOT NULL,
    title         TEXT NOT NULL,
    CONSTRAINT uq_control_ref UNIQUE (framework_id, ref_code)
);

CREATE TABLE control_assessment (
    assessment_id  SERIAL PRIMARY KEY,
    engagement_id  INT  NOT NULL REFERENCES engagement (engagement_id) ON DELETE CASCADE,
    control_id     INT  NOT NULL REFERENCES control (control_id),
    assessed_by    INT  NOT NULL REFERENCES consultant (consultant_id),
    rating         TEXT NOT NULL CHECK (rating IN ('compliant', 'partial', 'non_compliant', 'not_applicable')),
    assessed_on    DATE NOT NULL,
    notes          TEXT,
    -- One rating per control per engagement, so compliance percentages
    -- (Q3) cannot be inflated by duplicate assessments
    CONSTRAINT uq_assessment UNIQUE (engagement_id, control_id)
);

-- ---------------------------------------------------------------------
-- 6. Training and security awareness
-- ---------------------------------------------------------------------
CREATE TABLE training_session (
    session_id     SERIAL PRIMARY KEY,
    engagement_id  INT  NOT NULL REFERENCES engagement (engagement_id) ON DELETE CASCADE,
    trainer_id     INT  NOT NULL REFERENCES consultant (consultant_id),
    topic          TEXT NOT NULL,
    delivered_on   DATE NOT NULL,
    mode           TEXT NOT NULL CHECK (mode IN ('onsite', 'online'))
);

CREATE TABLE attendance (
    session_id         INT      NOT NULL REFERENCES training_session (session_id) ON DELETE CASCADE,
    -- Participants are client staff, not TerraCyb users, and are only
    -- identified for attendance, so an email is stored instead of a full
    -- person table (data minimisation, NDPA section 24)
    participant_email  TEXT     NOT NULL,
    quiz_score         SMALLINT CHECK (quiz_score BETWEEN 0 AND 100),
    PRIMARY KEY (session_id, participant_email)
);

-- ---------------------------------------------------------------------
-- 7. Billing
-- ---------------------------------------------------------------------
CREATE TABLE invoice (
    invoice_id     SERIAL PRIMARY KEY,
    engagement_id  INT           NOT NULL REFERENCES engagement (engagement_id),
    invoice_no     TEXT          NOT NULL UNIQUE,     -- the number printed on the invoice; must never repeat
    amount_ngn     NUMERIC(14,2) NOT NULL CHECK (amount_ngn > 0),
    issued_on      DATE          NOT NULL,
    due_on         DATE          NOT NULL,
    status         TEXT          NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'part_paid', 'paid', 'void')),
    CONSTRAINT ck_invoice_due CHECK (due_on >= issued_on)
);

-- Payments are a separate table, not a "paid" column on invoice, because
-- one invoice can be settled in several instalments (part payments).
CREATE TABLE payment (
    payment_id  SERIAL PRIMARY KEY,
    invoice_id  INT           NOT NULL REFERENCES invoice (invoice_id),
    amount_ngn  NUMERIC(14,2) NOT NULL CHECK (amount_ngn > 0),
    paid_on     DATE          NOT NULL,
    method      TEXT          NOT NULL CHECK (method IN ('bank_transfer', 'card', 'ussd'))
);

-- ---------------------------------------------------------------------
-- 8. Audit trail
-- ---------------------------------------------------------------------
-- No foreign key to the audited row on purpose: the audit trail must keep
-- its history even after that row is deleted. JSONB snapshots store the
-- whole row before and after the change, so one log table serves any
-- audited table, whatever its columns.
CREATE TABLE audit_log (
    log_id      BIGSERIAL PRIMARY KEY,
    table_name  TEXT        NOT NULL,
    record_id   BIGINT      NOT NULL,
    action      TEXT        NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT        NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Foreign key columns are not indexed automatically in PostgreSQL.
-- Index the ones used for joins and cascades.
CREATE INDEX idx_consultant_office    ON consultant (office_id);
CREATE INDEX idx_state_office         ON state (serving_office_id);
CREATE INDEX idx_client_state         ON client (state_code);
CREATE INDEX idx_site_client          ON client_site (client_id);
CREATE INDEX idx_engagement_client    ON engagement (client_id);
CREATE INDEX idx_staff_consultant     ON engagement_staff (consultant_id);
CREATE INDEX idx_asset_site           ON asset (site_id);
CREATE INDEX idx_finding_engagement   ON finding (engagement_id);
CREATE INDEX idx_finding_asset        ON finding (asset_id);
CREATE INDEX idx_control_framework    ON control (framework_id);
CREATE INDEX idx_invoice_engagement   ON invoice (engagement_id);
CREATE INDEX idx_payment_invoice      ON payment (invoice_id);

-- ---------------------------------------------------------------------
-- 9. Business rules that a CHECK constraint cannot express
-- ---------------------------------------------------------------------

-- Why triggers here: a CHECK constraint can only see the row being written,
-- but these rules compare rows in other tables. A trigger enforces them
-- inside the database, so no application or script can bypass them.
--
-- Rule 1: a finding's asset must belong to the engagement's client.
-- Reason: finding reaches the client by two paths (via engagement and via
-- asset -> site); without this check they could point at different clients.
CREATE FUNCTION fn_finding_asset_matches_client() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ead     -- fixed path: works from any session and blocks search_path hijacking
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM engagement e
        JOIN client_site s ON s.client_id = e.client_id
        JOIN asset a       ON a.site_id   = s.site_id
        WHERE e.engagement_id = NEW.engagement_id
          AND a.asset_id      = NEW.asset_id
    ) THEN
        RAISE EXCEPTION 'Asset % does not belong to the client of engagement %',
            NEW.asset_id, NEW.engagement_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_finding_asset_client
    BEFORE INSERT OR UPDATE OF asset_id, engagement_id ON finding
    FOR EACH ROW EXECUTE FUNCTION fn_finding_asset_matches_client();

-- Rule 2: total payments can never exceed the invoice amount.
-- Reason: an overpayment is a real accounting error, and part payments
-- mean the rule depends on the SUM of other rows, which CHECK cannot do.
-- Also keeps invoice.status in step with what has been paid.
CREATE FUNCTION fn_payment_within_invoice() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ead     -- fixed path: works from any session and blocks search_path hijacking
AS $$
DECLARE
    v_amount  NUMERIC(14,2);
    v_paid    NUMERIC(14,2);
BEGIN
    -- Lock the invoice row so two concurrent payments cannot both pass the check.
    SELECT amount_ngn INTO v_amount FROM invoice WHERE invoice_id = NEW.invoice_id FOR UPDATE;

    SELECT COALESCE(SUM(amount_ngn), 0) INTO v_paid
    FROM payment WHERE invoice_id = NEW.invoice_id;

    IF v_paid + NEW.amount_ngn > v_amount THEN
        RAISE EXCEPTION 'Payment of % NGN would exceed invoice % (amount %, already paid %)',
            NEW.amount_ngn, NEW.invoice_id, v_amount, v_paid;
    END IF;

    UPDATE invoice
    SET status = CASE WHEN v_paid + NEW.amount_ngn = v_amount THEN 'paid' ELSE 'part_paid' END
    WHERE invoice_id = NEW.invoice_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payment_within_invoice
    BEFORE INSERT ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_payment_within_invoice();

-- Rule 3: every change to a finding is written to the audit log.
-- Reason: findings are audit evidence for clients; who changed a status
-- and when must be traceable (accountability, NDPA section 24).
CREATE FUNCTION fn_audit_finding() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ead     -- fixed path: works from any session and blocks search_path hijacking
AS $$
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data)
    VALUES (
        'finding',
        COALESCE(NEW.finding_id, OLD.finding_id),
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Audit updates and deletes only: an INSERT is already recorded by the
-- new row itself, and skipping it keeps the bulk seed load fast.
CREATE TRIGGER trg_audit_finding
    AFTER UPDATE OR DELETE ON finding
    FOR EACH ROW EXECUTE FUNCTION fn_audit_finding();

-- ---------------------------------------------------------------------
-- 10. Reporting view used in later portfolios
-- ---------------------------------------------------------------------
-- The triage join (finding -> asset -> site -> client -> office) is needed
-- by several reports, so it is written once here instead of being
-- repeated, and possibly written slightly differently, in each query.
CREATE VIEW v_open_findings AS
SELECT c.client_id, c.name AS client_name, o.office_code AS serving_office, s.site_name, a.hostname,
       f.finding_id, f.title, f.cvss_score, f.severity, f.status, f.found_on,
       CURRENT_DATE - f.found_on AS days_open
FROM finding f
JOIN asset a       ON a.asset_id  = f.asset_id
JOIN client_site s ON s.site_id   = a.site_id
JOIN client c      ON c.client_id = s.client_id
JOIN state st      ON st.state_code = c.state_code        -- client's home state
JOIN office o      ON o.office_id   = st.serving_office_id -- office responsible for the client
WHERE f.status IN ('open', 'in_progress');
