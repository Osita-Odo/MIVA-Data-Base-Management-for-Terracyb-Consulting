-- =====================================================================
-- TerraCyber Consulting: Engagement and Assurance Database (EAD)
-- Portfolio 1: relational schema (PostgreSQL 16)
-- Run:  psql -d ead -f schema.sql
-- =====================================================================

DROP SCHEMA IF EXISTS ead CASCADE;
CREATE SCHEMA ead;
SET search_path TO ead;

-- ---------------------------------------------------------------------
-- 1. Organisation: offices and consultants
-- ---------------------------------------------------------------------
CREATE TABLE office (
    office_id     SERIAL PRIMARY KEY,
    office_name   TEXT        NOT NULL,
    city          TEXT        NOT NULL,
    country_code  CHAR(2)     NOT NULL,
    region        TEXT        NOT NULL CHECK (region IN ('EU', 'AFRICA', 'OTHER')),
    CONSTRAINT uq_office_city UNIQUE (city, country_code)
);

CREATE TABLE consultant (
    consultant_id    SERIAL PRIMARY KEY,
    office_id        INT          NOT NULL REFERENCES office (office_id),
    full_name        TEXT         NOT NULL,
    email            TEXT         NOT NULL UNIQUE,
    role             TEXT         NOT NULL CHECK (role IN ('analyst', 'lead', 'manager', 'trainer')),
    hire_date        DATE         NOT NULL,
    hourly_rate_eur  NUMERIC(8,2) NOT NULL CHECK (hourly_rate_eur > 0)
);

-- ---------------------------------------------------------------------
-- 2. Clients and their sites
-- ---------------------------------------------------------------------
CREATE TABLE client (
    client_id       SERIAL PRIMARY KEY,
    name            TEXT    NOT NULL UNIQUE,
    sector          TEXT    NOT NULL CHECK (sector IN ('ngo', 'public', 'private')),
    country_code    CHAR(2) NOT NULL,
    data_residency  TEXT    NOT NULL CHECK (data_residency IN ('EU', 'AFRICA', 'OTHER')),
    created_at      DATE    NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE client_site (
    site_id       SERIAL PRIMARY KEY,
    client_id     INT     NOT NULL REFERENCES client (client_id) ON DELETE CASCADE,
    site_name     TEXT    NOT NULL,
    city          TEXT    NOT NULL,
    country_code  CHAR(2) NOT NULL,
    CONSTRAINT uq_site_name UNIQUE (client_id, site_name)
);

-- ---------------------------------------------------------------------
-- 3. Services and engagements
-- ---------------------------------------------------------------------
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
    end_date            DATE,
    status              TEXT          NOT NULL CHECK (status IN ('planned', 'active', 'closed', 'cancelled')),
    budget_eur          NUMERIC(12,2) NOT NULL CHECK (budget_eur >= 0),
    CONSTRAINT ck_engagement_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Junction table: resolves the many-to-many between consultant and engagement
CREATE TABLE engagement_staff (
    engagement_id       INT          NOT NULL REFERENCES engagement (engagement_id) ON DELETE CASCADE,
    consultant_id       INT          NOT NULL REFERENCES consultant (consultant_id),
    role_on_engagement  TEXT         NOT NULL,
    hours_allocated     NUMERIC(6,1) NOT NULL CHECK (hours_allocated >= 0),
    PRIMARY KEY (engagement_id, consultant_id)
);

-- ---------------------------------------------------------------------
-- 4. Assets and vulnerability findings
-- ---------------------------------------------------------------------
CREATE TABLE asset (
    asset_id         SERIAL PRIMARY KEY,
    site_id          INT     NOT NULL REFERENCES client_site (site_id) ON DELETE CASCADE,
    hostname         TEXT    NOT NULL,
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
    invoice_no     TEXT          NOT NULL UNIQUE,
    amount_eur     NUMERIC(12,2) NOT NULL CHECK (amount_eur > 0),
    issued_on      DATE          NOT NULL,
    due_on         DATE          NOT NULL,
    status         TEXT          NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'part_paid', 'paid', 'void')),
    CONSTRAINT ck_invoice_due CHECK (due_on >= issued_on)
);

CREATE TABLE payment (
    payment_id  SERIAL PRIMARY KEY,
    invoice_id  INT           NOT NULL REFERENCES invoice (invoice_id),
    amount_eur  NUMERIC(12,2) NOT NULL CHECK (amount_eur > 0),
    paid_on     DATE          NOT NULL,
    method      TEXT          NOT NULL CHECK (method IN ('bank_transfer', 'card', 'mobile_money'))
);

-- ---------------------------------------------------------------------
-- 8. Audit trail
-- ---------------------------------------------------------------------
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

-- Rule 1: a finding's asset must belong to the engagement's client.
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
-- Also keeps invoice.status in step with what has been paid.
CREATE FUNCTION fn_payment_within_invoice() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ead     -- fixed path: works from any session and blocks search_path hijacking
AS $$
DECLARE
    v_amount  NUMERIC(12,2);
    v_paid    NUMERIC(12,2);
BEGIN
    -- Lock the invoice row so two concurrent payments cannot both pass the check.
    SELECT amount_eur INTO v_amount FROM invoice WHERE invoice_id = NEW.invoice_id FOR UPDATE;

    SELECT COALESCE(SUM(amount_eur), 0) INTO v_paid
    FROM payment WHERE invoice_id = NEW.invoice_id;

    IF v_paid + NEW.amount_eur > v_amount THEN
        RAISE EXCEPTION 'Payment of % EUR would exceed invoice % (amount %, already paid %)',
            NEW.amount_eur, NEW.invoice_id, v_amount, v_paid;
    END IF;

    UPDATE invoice
    SET status = CASE WHEN v_paid + NEW.amount_eur = v_amount THEN 'paid' ELSE 'part_paid' END
    WHERE invoice_id = NEW.invoice_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payment_within_invoice
    BEFORE INSERT ON payment
    FOR EACH ROW EXECUTE FUNCTION fn_payment_within_invoice();

-- Rule 3: every change to a finding is written to the audit log.
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

-- Audit updates and deletes only, so the bulk seed load stays fast.
CREATE TRIGGER trg_audit_finding
    AFTER UPDATE OR DELETE ON finding
    FOR EACH ROW EXECUTE FUNCTION fn_audit_finding();

-- ---------------------------------------------------------------------
-- 10. Reporting view used in later portfolios
-- ---------------------------------------------------------------------
CREATE VIEW v_open_findings AS
SELECT c.client_id, c.name AS client_name, s.site_name, a.hostname,
       f.finding_id, f.title, f.cvss_score, f.severity, f.status, f.found_on,
       CURRENT_DATE - f.found_on AS days_open
FROM finding f
JOIN asset a       ON a.asset_id  = f.asset_id
JOIN client_site s ON s.site_id   = a.site_id
JOIN client c      ON c.client_id = s.client_id
WHERE f.status IN ('open', 'in_progress');
