# Portfolio 1: Database Design and Modelling

**Case study:** TerraCyber Consulting, Engagement and Assurance Database (EAD)
**DBMS:** PostgreSQL 16
**Marks:** 7

## 1. What this portfolio delivers

| Evidence required by the brief | Where it is |
| --- | --- |
| Case study description | Section 2 below and the root [README](../README.md) |
| ER diagram | Section 3 (renders on GitHub) and `erd.dbml` (source for dbdiagram.io, exported as `erd.png`) |
| Relational schema | [`schema.sql`](schema.sql) |
| Keys and constraints | Section 4, tested by [`test_constraints.sql`](test_constraints.sql) |
| Normalisation explanation | Section 5 |
| Sample data | [`seed.sql`](seed.sql) (synthetic, deterministic) |

## 2. Case study in brief

TerraCyber Consulting is a Nigerian cybersecurity consultancy serving NGOs, public bodies and private firms in all six geopolitical zones. It works from three sites, Lagos (headquarters), Abuja and Port Harcourt; [../docs/site-selection.md](../docs/site-selection.md) explains why. It runs three service lines: compliance and data protection, advisory and resilience, and training and security awareness. Engagements are budgeted and invoiced in naira (NGN).

The EAD supports these operations:

- open an engagement for a client and staff it with consultants;
- record client assets and log vulnerability findings against them;
- assess a client against ISO/IEC 27001:2022, the Nigeria Data Protection Act 2023 (NDPA) or NIST CSF 2.0;
- deliver training sessions and record attendance and quiz scores;
- invoice engagements and record payments;
- keep an audit trail of every change to a finding.

## 3. ER diagram

```mermaid
erDiagram
    OFFICE ||--o{ CONSULTANT : employs
    OFFICE ||--o{ STATE : serves
    STATE ||--o{ CLIENT : located_in
    STATE ||--o{ CLIENT_SITE : located_in
    CLIENT ||--|{ CLIENT_SITE : has
    CLIENT_SITE ||--o{ ASSET : hosts
    CLIENT ||--o{ ENGAGEMENT : commissions
    SERVICE_LINE ||--o{ ENGAGEMENT : classifies
    CONSULTANT ||--o{ ENGAGEMENT : leads
    ENGAGEMENT ||--|{ ENGAGEMENT_STAFF : staffed_by
    CONSULTANT ||--o{ ENGAGEMENT_STAFF : works_on
    ENGAGEMENT ||--o{ FINDING : produces
    ASSET ||--o{ FINDING : affected_by
    FRAMEWORK ||--|{ CONTROL : contains
    ENGAGEMENT ||--o{ CONTROL_ASSESSMENT : includes
    CONTROL ||--o{ CONTROL_ASSESSMENT : assessed_in
    CONSULTANT ||--o{ CONTROL_ASSESSMENT : performs
    ENGAGEMENT ||--o{ TRAINING_SESSION : delivers
    CONSULTANT ||--o{ TRAINING_SESSION : trains
    TRAINING_SESSION ||--o{ ATTENDANCE : records
    ENGAGEMENT ||--o{ INVOICE : billed_by
    INVOICE ||--o{ PAYMENT : settled_by

    OFFICE {
        int office_id PK
        char office_code UK "LOS ABV PHC"
        text city
        text db_role
    }
    STATE {
        char state_code PK
        text state_name UK
        text geopolitical_zone
        int serving_office_id FK
    }
    CLIENT {
        int client_id PK
        text name UK
        text sector
        char state_code FK
    }
    ENGAGEMENT {
        int engagement_id PK
        int client_id FK
        smallint service_id FK
        int lead_consultant_id FK
        date start_date
        date end_date
        text status
        numeric budget_ngn
    }
    ENGAGEMENT_STAFF {
        int engagement_id PK, FK
        int consultant_id PK, FK
        numeric hours_allocated
    }
    FINDING {
        bigint finding_id PK
        int engagement_id FK
        int asset_id FK
        text cve_id
        numeric cvss_score
        text severity "generated"
        text status
    }
    CONTROL_ASSESSMENT {
        int assessment_id PK
        int engagement_id FK
        int control_id FK
        text rating
    }
    INVOICE {
        int invoice_id PK
        int engagement_id FK
        numeric amount_ngn
    }
    PAYMENT {
        int payment_id PK
        int invoice_id FK
        numeric amount_ngn
    }
```

The full attribute list for all 18 tables is in `erd.dbml`. Export it from dbdiagram.io as `erd.png` and commit the image.

`audit_log` has no foreign key on purpose. It must keep its history even after the row it describes is deleted.

## 4. Keys and constraints

**18 tables.** Every table has a primary key; `state` uses a natural key (the two-letter state code). Two tables use composite keys:

| Table | Primary key | Why composite |
| --- | --- | --- |
| `engagement_staff` | (engagement_id, consultant_id) | Resolves the many-to-many between consultants and engagements. A consultant appears once per engagement. |
| `attendance` | (session_id, participant_email) | A participant attends a session once. |

**Constraint types used:**

| Type | Examples | Business reason |
| --- | --- | --- |
| `UNIQUE` | consultant.email, invoice.invoice_no, (framework_id, ref_code) | No duplicate staff logins, invoice numbers or control codes |
| `FOREIGN KEY` | 22 references, `ON DELETE CASCADE` for child rows such as sites and attendance | Referential integrity |
| `CHECK` (domain) | sector, status, rating, role, asset_type | Only known values are stored |
| `CHECK` (range) | cvss_score 0 to 10, quiz_score 0 to 100, amounts > 0 | Rejects impossible numbers |
| `CHECK` (row rule) | end_date >= start_date; status `fixed` if and only if fixed_on is set | Keeps dates and status consistent |
| `CHECK` (pattern) | cve_id matches `^CVE-[0-9]{4}-[0-9]{4,}$` | Valid CVE identifiers only |
| Generated column | finding.severity from cvss_score | Severity cannot disagree with the score |
| Triggers | asset must belong to the engagement's client; payments cannot exceed invoice; audit of finding changes | Rules spanning several tables, which CHECK cannot express |

**Test evidence:** run `test_constraints.sql`. Each of its 12 statements breaks one rule and must fail.

```bash
psql -d ead -f test_constraints.sql 2>&1 | tee constraint-test-output.txt
```

## 5. Normalisation

### Starting point: the unnormalised spreadsheet (UNF)

Before a database, an engagement tracker in a spreadsheet often looks like this:

| Engagement | Client | Client state | Zone | Serving office | Staff | Findings |
| --- | --- | --- | --- | --- | --- |
| E-2 | Sahel Water Alliance | Borno | North East | Abuja | Ngozi Eze (lead, 40h); Musa Bello (analyst, 80h) | fw-01: TLS 1.0 (5.3, medium); srv-02: Log4Shell CVE-2021-44228 (10.0, critical) |

Problems: several staff and findings are packed in one cell; the client's state, zone and serving office repeat on every engagement row; and severity can contradict the score.

### First normal form (1NF)

Every cell holds one atomic value and there are no repeating groups. Staff and findings move to their own rows, giving `engagement_staff` and `finding`.

### Second normal form (2NF)

No non-key attribute depends on only part of a composite key. In `engagement_staff (engagement_id, consultant_id)`, `hours_allocated` depends on both keys. The consultant's name and email depend on `consultant_id` alone, so they move to `consultant`.

### Third normal form (3NF)

No non-key attribute depends on another non-key attribute:

- client name, sector and state depend on the client, not the engagement, so they live in `client`;
- **geopolitical zone and serving office depend on the state, not on the client.** Keeping them in `client` would create the transitive dependency client_id -> state_code -> geopolitical_zone. They live in the `state` table, so moving a state to another office is a one-row update;
- the service name depends on `service_id`, so it lives in `service_line`;
- a site's city depends on the site, and the asset only references `site_id`;
- `severity` depends on `cvss_score`. Storing it as a normal column would break 3NF. It is a **generated column**, so the DBMS derives it and nobody can update it on its own.

### Deliberate exceptions

- `finding.engagement_id` and `finding.asset_id` both point towards the client. That is a redundant path, so a trigger enforces that they agree.
- `audit_log` stores JSON snapshots. It is a history table, not live data, so normal forms do not apply.

## 6. How to run and test

```bash
createdb ead
psql -d ead -f schema.sql
psql -d ead -f seed.sql            # loads data and prints row counts
psql -d ead -f test_constraints.sql
```

Seed data volumes (deterministic, `setseed(0.42)`):

| Table | Rows |
| --- | --- |
| client / client_site / asset | 20 / 50 / 850 |
| engagement / engagement_staff | 60 / 180 |
| finding | 66,240 |
| office / state | 3 / 37 |
| control / control_assessment | 128 / 2,340 |
| training_session / attendance | 60 / 960 |
| invoice / payment | 120 / 114 |

All names, organisations, hostnames and IP addresses in the seed data are fictitious. The CVE identifiers are real, public vulnerabilities used as realistic examples.

## 7. Evidence checklist

- [ ] `erd.png` exported from `erd.dbml`
- [ ] Screenshot of `\dt ead.*` listing the 18 tables
- [ ] Screenshot of the seed row counts
- [ ] `constraint-test-output.txt` showing the 12 expected errors
