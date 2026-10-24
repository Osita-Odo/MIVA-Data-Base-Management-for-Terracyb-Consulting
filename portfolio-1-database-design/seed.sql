-- =====================================================================
-- TerraCyber Consulting EAD: synthetic seed data
-- All people, clients, hosts and IP addresses are fictitious.
-- Volumes are large enough for Portfolio 2 (about 66,000 findings).
-- Run after schema.sql:  psql -d ead -f seed.sql
-- =====================================================================
SET search_path TO ead;
SELECT setseed(0.42);   -- same data on every run, so results and screenshots are reproducible (D30)

BEGIN;

-- ---------------------------------------------------------------------
-- Offices: the three Nigerian sites chosen in docs/site-selection.md
--   LOS  Lagos          headquarters, primary database
--   ABV  Abuja          public-sector shard (NITDA cloud policy, regulators)
--   PHC  Port Harcourt  disaster-recovery standby (second subsea route)
-- ---------------------------------------------------------------------
INSERT INTO office (office_code, office_name, city, site_role, db_role) VALUES
    ('LOS', 'TerraCyber Lagos',         'Lagos',         'headquarters', 'primary'),
    ('ABV', 'TerraCyber Abuja',         'Abuja',         'regional',     'public_sector_shard'),
    ('PHC', 'TerraCyber Port Harcourt', 'Port Harcourt', 'regional',     'standby');

-- ---------------------------------------------------------------------
-- States: 36 states and the FCT with their geopolitical zones.
-- Serving office by zone: South West -> Lagos; North Central, North East
-- and North West -> Abuja; South South and South East -> Port Harcourt.
-- ---------------------------------------------------------------------
INSERT INTO state (state_code, state_name, geopolitical_zone, serving_office_id)
SELECT v.code, v.name, v.zone,
       (SELECT office_id FROM office WHERE office_code =
            CASE v.zone WHEN 'South West'  THEN 'LOS'
                        WHEN 'South South' THEN 'PHC'
                        WHEN 'South East'  THEN 'PHC'
                        ELSE 'ABV' END)
FROM (VALUES
    ('AB', 'Abia',        'South East'),    ('AD', 'Adamawa',   'North East'),
    ('AK', 'Akwa Ibom',   'South South'),   ('AN', 'Anambra',   'South East'),
    ('BA', 'Bauchi',      'North East'),    ('BY', 'Bayelsa',   'South South'),
    ('BE', 'Benue',       'North Central'), ('BO', 'Borno',     'North East'),
    ('CR', 'Cross River', 'South South'),   ('DE', 'Delta',     'South South'),
    ('EB', 'Ebonyi',      'South East'),    ('ED', 'Edo',       'South South'),
    ('EK', 'Ekiti',       'South West'),    ('EN', 'Enugu',     'South East'),
    ('FC', 'Federal Capital Territory', 'North Central'),
    ('GO', 'Gombe',       'North East'),    ('IM', 'Imo',       'South East'),
    ('JI', 'Jigawa',      'North West'),    ('KD', 'Kaduna',    'North West'),
    ('KN', 'Kano',        'North West'),    ('KT', 'Katsina',   'North West'),
    ('KE', 'Kebbi',       'North West'),    ('KO', 'Kogi',      'North Central'),
    ('KW', 'Kwara',       'North Central'), ('LA', 'Lagos',     'South West'),
    ('NA', 'Nasarawa',    'North Central'), ('NI', 'Niger',     'North Central'),
    ('OG', 'Ogun',        'South West'),    ('ON', 'Ondo',      'South West'),
    ('OS', 'Osun',        'South West'),    ('OY', 'Oyo',       'South West'),
    ('PL', 'Plateau',     'North Central'), ('RI', 'Rivers',    'South South'),
    ('SO', 'Sokoto',      'North West'),    ('TA', 'Taraba',    'North East'),
    ('YO', 'Yobe',        'North East'),    ('ZA', 'Zamfara',   'North West')
) AS v(code, name, zone);

-- ---------------------------------------------------------------------
-- Consultants: 24 staff spread over the three offices
-- Hourly rates in naira (NGN), by seniority. The figures are illustrative,
-- set so that some engagements exceed budget and Q5 has risks to flag (D33)
-- ---------------------------------------------------------------------
INSERT INTO consultant (office_id, full_name, email, role, hire_date, hourly_rate_ngn)
SELECT
    1 + (g % 3),                                              -- round-robin over the offices
    first_names[1 + (g % array_length(first_names, 1))] || ' ' ||
        last_names[1 + ((g * 7) % array_length(last_names, 1))],
    'consultant' || g || '@terracyb.example',
    CASE WHEN g <= 3 THEN 'manager'
         WHEN g <= 9 THEN 'lead'
         WHEN g <= 13 THEN 'trainer'
         ELSE 'analyst' END,
    DATE '2021-01-04' + (g * 37),
    CASE WHEN g <= 3 THEN 84000 WHEN g <= 9 THEN 69000 WHEN g <= 13 THEN 57000 ELSE 48000 END
FROM generate_series(1, 24) AS g,
     LATERAL (SELECT ARRAY['Amara','Tunde','Ngozi','Bola','Chidi','Halima','Emeka','Aisha',
                           'Segun','Ifeoma','Musa','Ebere'] AS first_names,
                     ARRAY['Okafor','Bello','Adeyemi','Eze','Ibrahim','Nwosu','Ogunleye',
                           'Danjuma','Okon','Usman','Etim','Akande'] AS last_names) n;

-- ---------------------------------------------------------------------
-- Service lines (fixed reference data)
-- ---------------------------------------------------------------------
INSERT INTO service_line (service_id, name) VALUES
    (1, 'Compliance and data protection'),
    (2, 'Advisory and resilience'),
    (3, 'Training and security awareness');

-- ---------------------------------------------------------------------
-- Clients: 20 fictitious Nigerian organisations across NGO, public and
-- private sectors, spread over all six geopolitical zones.
-- The temp table also holds each client's head-office and field cities.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE client_src (n INT, name TEXT, sector TEXT, hq_city TEXT, hq_state CHAR(2),
                              field_city TEXT, field_state CHAR(2));
INSERT INTO client_src VALUES
    ( 1, 'Lagoon Community Food Network',  'ngo',     'Lagos',         'LA', 'Abeokuta',      'OG'),
    ( 2, 'Sahel Water Alliance',           'ngo',     'Maiduguri',     'BO', 'Damaturu',      'YO'),
    ( 3, 'Benue Valley Health Trust',      'ngo',     'Makurdi',       'BE', 'Lafia',         'NA'),
    ( 4, 'Northern Girls Education Fund',  'ngo',     'Kano',          'KN', 'Dutse',         'JI'),
    ( 5, 'Delta Mangrove Trust',           'ngo',     'Port Harcourt', 'RI', 'Yenagoa',       'BY'),
    ( 6, 'Federal Archives Service',       'public',  'Abuja',         'FC', 'Minna',         'NI'),
    ( 7, 'Rivers Coastal Pensions Board',  'public',  'Port Harcourt', 'RI', 'Uyo',           'AK'),
    ( 8, 'Kano Municipal Revenue Office',  'public',  'Kano',          'KN', 'Katsina',       'KT'),
    ( 9, 'Oyo Health Records Agency',      'public',  'Ibadan',        'OY', 'Oshogbo',       'OS'),
    (10, 'Enugu Urban Transit Board',      'public',  'Enugu',         'EN', 'Abakaliki',     'EB'),
    (11, 'Greenfield Microfinance Bank',   'private', 'Lagos',         'LA', 'Ibadan',        'OY'),
    (12, 'Atlas Logistics Nigeria',        'private', 'Lagos',         'LA', 'Kano',          'KN'),
    (13, 'Savanna Mobile Money',           'private', 'Abuja',         'FC', 'Kaduna',        'KD'),
    (14, 'Harbour Insurance Plc',          'private', 'Lagos',         'LA', 'Port Harcourt', 'RI'),
    (15, 'Nova Retail Group',              'private', 'Ibadan',        'OY', 'Akure',         'ON'),
    (16, 'Niger Delta Offshore Services',  'private', 'Port Harcourt', 'RI', 'Warri',         'DE'),
    (17, 'Creekside Energy Services',      'private', 'Warri',         'DE', 'Benin City',    'ED'),
    (18, 'Pioneer Agritech',               'private', 'Kaduna',        'KD', 'Jos',           'PL'),
    (19, 'Meridian Hotels',                'private', 'Abuja',         'FC', 'Lagos',         'LA'),
    (20, 'Unity Property Partners',        'private', 'Enugu',         'EN', 'Owerri',        'IM');

INSERT INTO client (name, sector, state_code, created_at)
SELECT name, sector, hq_state, DATE '2022-01-10' + n * 41
FROM client_src
ORDER BY n;                                   -- client_id follows n

-- ---------------------------------------------------------------------
-- Client sites: head office, data centre, and a field office for even ids.
-- The data centre is placed in the city of the client's serving office,
-- where the colocation facilities are (Lagos, Abuja, Port Harcourt).
-- ---------------------------------------------------------------------
INSERT INTO client_site (client_id, site_name, city, state_code)
SELECT c.client_id,
       x.site_name, x.city, x.state_code
FROM client c
JOIN client_src src ON src.n = c.client_id
JOIN state st       ON st.state_code = c.state_code
JOIN office o       ON o.office_id   = st.serving_office_id
CROSS JOIN LATERAL (VALUES
    (1, 'Head office',  src.hq_city,    src.hq_state),
    (2, 'Data centre',  o.city,         CASE o.office_code WHEN 'LOS' THEN 'LA'
                                                           WHEN 'ABV' THEN 'FC'
                                                           ELSE 'RI' END),
    (3, 'Field office', src.field_city, src.field_state)
) AS x(k, site_name, city, state_code)
WHERE x.k <= 2 OR c.client_id % 2 = 0
ORDER BY c.client_id, x.k;

-- ---------------------------------------------------------------------
-- Assets: 8 to 20 per site
-- ---------------------------------------------------------------------
INSERT INTO asset (site_id, hostname, ip_address, asset_type, criticality, internet_facing)
SELECT s.site_id,
       lower(substr(replace(c.name, ' ', ''), 1, 6)) || '-' || s.site_id || '-' || lpad(n::text, 3, '0'),
       ('10.' || (s.site_id % 250) || '.' || (n / 250) || '.' || (1 + n % 250))::inet,
       (ARRAY['server','workstation','network','cloud','application'])[1 + floor(random() * 5)::int],
       (ARRAY['low','medium','medium','high','critical'])[1 + floor(random() * 5)::int],
       random() < 0.15
FROM client_site s
JOIN client c ON c.client_id = s.client_id
CROSS JOIN LATERAL generate_series(1, 8 + floor(random() * 13)::int) AS n;

-- ---------------------------------------------------------------------
-- Engagements: 3 per client, one per service line, spread over 2023-2026
-- ---------------------------------------------------------------------
INSERT INTO engagement (client_id, service_id, lead_consultant_id, title,
                        start_date, end_date, status, budget_ngn)
SELECT c.client_id,
       sl.service_id,
       4 + ((c.client_id + sl.service_id) % 6),          -- leads are consultants 4-9
       sl.name || ' for ' || c.name,
       d.start_date,
       CASE WHEN d.start_date < DATE '2026-03-01' THEN d.start_date + 90 + (c.client_id * 3) END,
       CASE WHEN d.start_date >= DATE '2026-09-01' THEN 'planned'
            WHEN d.start_date >= DATE '2026-03-01' THEN 'active'
            ELSE 'closed' END,
       (7200000 + c.client_id * 900000 + sl.service_id * 2400000)::numeric   -- budget in naira
FROM client c
CROSS JOIN service_line sl
CROSS JOIN LATERAL (SELECT DATE '2023-02-01' + ((c.client_id * 53 + sl.service_id * 97) % 1310) AS start_date) d
ORDER BY sl.service_id, c.client_id;     -- ids 1-20 compliance, 21-40 advisory, 41-60 training

-- Staff on each engagement: the lead plus 1-3 analysts or trainers
INSERT INTO engagement_staff (engagement_id, consultant_id, role_on_engagement, hours_allocated)
SELECT e.engagement_id, e.lead_consultant_id, 'Engagement lead', 40 + (e.engagement_id % 5) * 10
FROM engagement e;

INSERT INTO engagement_staff (engagement_id, consultant_id, role_on_engagement, hours_allocated)
SELECT DISTINCT ON (e.engagement_id, cons_id)
       e.engagement_id, cons_id,
       CASE WHEN e.service_id = 3 THEN 'Trainer' ELSE 'Analyst' END,
       60 + floor(random() * 100)
FROM engagement e
CROSS JOIN LATERAL generate_series(1, 1 + (e.engagement_id % 3)) AS k
CROSS JOIN LATERAL (
    SELECT CASE WHEN e.service_id = 3 THEN 10 + ((e.engagement_id + k) % 4)     -- trainers 10-13
                ELSE 14 + ((e.engagement_id * 3 + k) % 11) END AS cons_id         -- analysts 14-24
) x;

-- ---------------------------------------------------------------------
-- Findings: about 66,000 for compliance and advisory engagements
-- Templates mix generic weaknesses with well-known public CVEs.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE finding_template (id INT, title TEXT, cve_id TEXT, base_cvss NUMERIC);
INSERT INTO finding_template VALUES
    (1,  'Outdated TLS configuration allows TLS 1.0',             NULL, 5.3),
    (2,  'Default credentials on administrative interface',       NULL, 9.1),
    (3,  'Missing operating system security patches',             NULL, 7.5),
    (4,  'SMB signing not required',                              NULL, 5.9),
    (5,  'Weak password policy for domain accounts',              NULL, 6.5),
    (6,  'Remote Desktop exposed to the internet',                NULL, 8.1),
    (7,  'Unsupported operating system in production',            NULL, 7.8),
    (8,  'Missing HTTP security headers',                         NULL, 3.7),
    (9,  'SQL injection in login form',                           NULL, 9.8),
    (10, 'Excessive privileges on service account',               NULL, 6.8),
    (11, 'Unencrypted backup storage',                            NULL, 6.2),
    (12, 'Multi-factor authentication not enforced for VPN',      NULL, 8.0),
    (13, 'Verbose error messages disclose stack traces',          NULL, 4.3),
    (14, 'Self-signed certificate on internal portal',            NULL, 2.6),
    (15, 'Apache Log4j remote code execution (Log4Shell)',        'CVE-2021-44228', 10.0),
    (16, 'PAN-OS GlobalProtect command injection',                'CVE-2024-3400',  10.0),
    (17, 'Citrix NetScaler session token leak (Citrix Bleed)',    'CVE-2023-4966',  9.4),
    (18, 'Windows RDP remote code execution (BlueKeep)',          'CVE-2019-0708',  9.8),
    (19, 'MOVEit Transfer SQL injection',                         'CVE-2023-34362', 9.8),
    (20, 'Windows Print Spooler remote code execution',           'CVE-2021-34527', 8.8);

-- Asset id arrays per client, so each finding picks an asset from the right client
CREATE TEMP TABLE client_assets AS
SELECT s.client_id, array_agg(a.asset_id ORDER BY a.asset_id) AS ids
FROM asset a JOIN client_site s ON s.site_id = a.site_id
GROUP BY s.client_id;

CREATE TEMP TABLE finding_stage AS
SELECT e.engagement_id,
       ca.ids[1 + floor(random() * array_length(ca.ids, 1))::int] AS asset_id,
       1 + floor(random() * 20)::int AS template_id,
       e.start_date + floor(random() * GREATEST(1, COALESCE(e.end_date, DATE '2026-10-01') - e.start_date))::int AS found_on,
       random() AS r_status,
       random() AS r_cvss,
       random() AS r_days
FROM engagement e
JOIN client_assets ca ON ca.client_id = e.client_id
CROSS JOIN LATERAL generate_series(1, 1200 + (e.engagement_id * 37) % 1100) AS g
WHERE e.service_id IN (1, 2) AND e.status <> 'planned';

INSERT INTO finding (engagement_id, asset_id, title, cve_id, cvss_score, status, found_on, fixed_on)
SELECT fs.engagement_id, fs.asset_id, t.title, t.cve_id,
       CASE WHEN t.cve_id IS NOT NULL THEN t.base_cvss
            ELSE LEAST(10, GREATEST(0.1, round(t.base_cvss + (fs.r_cvss::numeric - 0.5) * 2, 1))) END,
       st.status,
       fs.found_on,
       CASE WHEN st.status = 'fixed' THEN fs.found_on + 1 + floor(fs.r_days * 120)::int END
FROM finding_stage fs
JOIN finding_template t ON t.id = fs.template_id
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN fs.found_on < DATE '2026-01-01' AND fs.r_status < 0.85 THEN 'fixed'
        WHEN fs.r_status < 0.45 THEN 'fixed'
        WHEN fs.r_status < 0.70 THEN 'open'
        WHEN fs.r_status < 0.92 THEN 'in_progress'
        ELSE 'accepted' END AS status
) st;

-- ---------------------------------------------------------------------
-- Frameworks and controls
-- ---------------------------------------------------------------------
INSERT INTO framework (name, version) VALUES
    ('ISO/IEC 27001', '2022'),
    ('Nigeria Data Protection Act', '2023'),
    ('NIST CSF',      '2.0');

-- ISO/IEC 27001:2022 Annex A has 93 controls in four themes:
-- A.5 organisational (37), A.6 people (8), A.7 physical (14), A.8 technological (34)
INSERT INTO control (framework_id, ref_code, title)
SELECT 1, 'A.' || t.theme || '.' || n, t.label || ' control A.' || t.theme || '.' || n
FROM (VALUES (5, 37, 'Organisational'), (6, 8, 'People'),
             (7, 14, 'Physical'),       (8, 34, 'Technological')) AS t(theme, cnt, label)
CROSS JOIN LATERAL generate_series(1, t.cnt) AS n;

INSERT INTO control (framework_id, ref_code, title) VALUES
    -- Nigeria Data Protection Act 2023: section numbers and headings as in the Act
    (2, 'S.24', 'Principles of personal data processing'),
    (2, 'S.25', 'Lawful basis of personal data processing'),
    (2, 'S.26', 'Consent'),
    (2, 'S.27', 'Provision of information to the data subject'),
    (2, 'S.28', 'Data privacy impact assessment'),
    (2, 'S.29', 'Obligations of the data controller and data processor'),
    (2, 'S.30', 'Sensitive personal data'),
    (2, 'S.32', 'Data Protection Officers'),
    (2, 'S.34', 'Rights of a data subject'),
    (2, 'S.39', 'Security, integrity, and confidentiality'),
    (2, 'S.40', 'Personal data breaches'),
    (2, 'S.41', 'Basis for cross-border transfer of personal data'),
    (2, 'S.44', 'Registration of data controllers and data processors of major importance'),
    (3, 'GV.OC', 'Organizational Context'),
    (3, 'GV.RM', 'Risk Management Strategy'),
    (3, 'GV.RR', 'Roles, Responsibilities, and Authorities'),
    (3, 'GV.PO', 'Policy'),
    (3, 'GV.OV', 'Oversight'),
    (3, 'GV.SC', 'Cybersecurity Supply Chain Risk Management'),
    (3, 'ID.AM', 'Asset Management'),
    (3, 'ID.RA', 'Risk Assessment'),
    (3, 'ID.IM', 'Improvement'),
    (3, 'PR.AA', 'Identity Management, Authentication, and Access Control'),
    (3, 'PR.AT', 'Awareness and Training'),
    (3, 'PR.DS', 'Data Security'),
    (3, 'PR.PS', 'Platform Security'),
    (3, 'PR.IR', 'Technology Infrastructure Resilience'),
    (3, 'DE.CM', 'Continuous Monitoring'),
    (3, 'DE.AE', 'Adverse Event Analysis'),
    (3, 'RS.MA', 'Incident Management'),
    (3, 'RS.AN', 'Incident Analysis'),
    (3, 'RS.CO', 'Incident Response Reporting and Communication'),
    (3, 'RS.MI', 'Incident Mitigation'),
    (3, 'RC.RP', 'Incident Recovery Plan Execution'),
    (3, 'RC.CO', 'Incident Recovery Communication');

-- Each compliance engagement assesses every ISO control and every NDPA
-- section (all clients process personal data in Nigeria). Private-sector
-- clients are also assessed against NIST CSF 2.0.
INSERT INTO control_assessment (engagement_id, control_id, assessed_by, rating, assessed_on, notes)
SELECT e.engagement_id, ctl.control_id,
       14 + ((e.engagement_id + ctl.control_id) % 11),
       CASE WHEN r < 0.03 THEN 'not_applicable'
            WHEN r < 0.03 + q THEN 'compliant'
            WHEN r < 0.03 + q + 0.15 THEN 'partial'
            ELSE 'non_compliant' END,
       e.start_date + 14 + (ctl.control_id % 30),
       NULL
FROM engagement e
JOIN client c ON c.client_id = e.client_id
JOIN control ctl
  ON ctl.framework_id = 1
  OR ctl.framework_id = 2
  OR (ctl.framework_id = 3 AND c.sector = 'private')
-- ctl.control_id is referenced so random() is drawn once per row, not once per client
CROSS JOIN LATERAL (SELECT random() + 0 * ctl.control_id AS r,
                           0.40 + (c.client_id % 5) * 0.09 AS q) x   -- clients differ in maturity
WHERE e.service_id = 1 AND e.status <> 'planned';

-- ---------------------------------------------------------------------
-- Training sessions and attendance
-- ---------------------------------------------------------------------
INSERT INTO training_session (engagement_id, trainer_id, topic, delivered_on, mode)
SELECT e.engagement_id,
       10 + ((e.engagement_id + k) % 4),
       (ARRAY['Phishing awareness', 'Password and MFA hygiene', 'Safe handling of beneficiary data',
              'Incident reporting basics', 'Secure use of mobile devices'])[1 + (e.engagement_id + k) % 5],
       e.start_date + k * 14,
       CASE WHEN k % 2 = 0 THEN 'online' ELSE 'onsite' END
FROM engagement e
CROSS JOIN LATERAL generate_series(1, 2 + e.engagement_id % 3) AS k
WHERE e.service_id = 3 AND e.status <> 'planned';

INSERT INTO attendance (session_id, participant_email, quiz_score)
SELECT ts.session_id,
       'participant' || p || '.c' || e.client_id || '@client.example',
       CASE WHEN random() < 0.1 THEN NULL ELSE 40 + floor(random() * 61)::int END
FROM training_session ts
JOIN engagement e ON e.engagement_id = ts.engagement_id
CROSS JOIN LATERAL generate_series(1, 10 + floor(random() * 16)::int) AS p;

-- ---------------------------------------------------------------------
-- Invoices and payments (payments go through the trigger)
-- ---------------------------------------------------------------------
INSERT INTO invoice (engagement_id, invoice_no, amount_ngn, issued_on, due_on)
SELECT e.engagement_id,
       'TCC-' || to_char(e.start_date + k * 30, 'YYYY') || '-' || lpad((e.engagement_id * 10 + k)::text, 5, '0'),
       round(e.budget_ngn / 2, 2),              -- two instalments of half the budget
       e.start_date + k * 30,
       e.start_date + k * 30 + 30
FROM engagement e
CROSS JOIN generate_series(1, 2) AS k
WHERE e.status <> 'planned';

-- Full payment for invoices issued before 2026-06; half payment for some later ones
INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
SELECT i.invoice_id, i.amount_ngn, i.issued_on + 20,
       (ARRAY['bank_transfer', 'card', 'ussd'])[1 + i.invoice_id % 3]
FROM invoice i
WHERE i.issued_on < DATE '2026-06-01'
ORDER BY i.invoice_id;

INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
SELECT i.invoice_id, round(i.amount_ngn / 2, 2), i.issued_on + 15, 'bank_transfer'
FROM invoice i
WHERE i.issued_on >= DATE '2026-06-01' AND i.invoice_id % 2 = 0
ORDER BY i.invoice_id;

COMMIT;

-- Refresh planner statistics after the bulk load
ANALYZE;

-- Row counts for the README
SELECT 'office' AS table_name, count(*) FROM office
UNION ALL SELECT 'state', count(*) FROM state
UNION ALL SELECT 'consultant', count(*) FROM consultant
UNION ALL SELECT 'client', count(*) FROM client
UNION ALL SELECT 'client_site', count(*) FROM client_site
UNION ALL SELECT 'service_line', count(*) FROM service_line
UNION ALL SELECT 'engagement', count(*) FROM engagement
UNION ALL SELECT 'engagement_staff', count(*) FROM engagement_staff
UNION ALL SELECT 'asset', count(*) FROM asset
UNION ALL SELECT 'finding', count(*) FROM finding
UNION ALL SELECT 'framework', count(*) FROM framework
UNION ALL SELECT 'control', count(*) FROM control
UNION ALL SELECT 'control_assessment', count(*) FROM control_assessment
UNION ALL SELECT 'training_session', count(*) FROM training_session
UNION ALL SELECT 'attendance', count(*) FROM attendance
UNION ALL SELECT 'invoice', count(*) FROM invoice
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'audit_log', count(*) FROM audit_log;
