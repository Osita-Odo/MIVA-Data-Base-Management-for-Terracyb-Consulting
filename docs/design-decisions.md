# Design Decisions and Reasons

This register lists every significant decision in the TerraCyb Consulting database portfolio. For each one it states **what was decided**, **what else was considered**, and **why** this option was chosen. Decision IDs (D01, D02, ...) are referenced from the code comments and the portfolio READMEs, so any design choice can be traced back to its reason.

**How to read the tables:** "Alternatives considered" names the realistic options that were rejected. "Reason" gives the deciding argument, with evidence where it exists. "Where" points to the file that implements the decision.

## Contents

1. [Case study and scope](#1-case-study-and-scope)
2. [Platform and tools](#2-platform-and-tools)
3. [Portfolio 1: schema design](#3-portfolio-1-schema-design)
4. [Portfolio 1: sample data](#4-portfolio-1-sample-data)
5. [Portfolio 2: queries and optimisation](#5-portfolio-2-queries-and-optimisation)
6. [Portfolio 3: transactions and concurrency](#6-portfolio-3-transactions-and-concurrency)
7. [Portfolio 4: NoSQL models](#7-portfolio-4-nosql-models)
8. [Portfolio 5: distribution and siting](#8-portfolio-5-distribution-and-siting)
9. [Evidence and working method](#9-evidence-and-working-method)

## 1. Case study and scope

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D01 | Use **TerraCyb Consulting**, a cybersecurity consultancy, as the single case study for all five portfolios | The example case studies in the brief (university, bank, hospital, e-commerce) | The brief asks for one realistic organisation "with enough data and processes" for design, SQL, transactions, NoSQL and distribution. TerraCyb has all five naturally: many related entities (clients, engagements, assets, findings); money and status changes that need transactions; audit evidence whose shape varies (suits documents); network exposure (suits a graph); and multiple offices (suits distribution). It is also a domain the student works in, which makes the design choices explainable at a verification call. | Root README |
| D02 | Operate from **three Nigerian sites: Lagos, Abuja and Port Harcourt** | Bonn, Lagos and Nairobi (first version); Kano, Enugu or Ibadan as second or third site | Chosen by a weighted scoring of data centres, independent internet routes, client demand, regulator proximity, security, distance from Lagos and flood risk. Lagos leads on every infrastructure measure; Abuja scored 80/100 and Port Harcourt 68/100, ahead of Kano and Enugu (57) and Ibadan (47). Full evidence and sources: [site-selection.md](site-selection.md). | `docs/site-selection.md`, `office` and `state` tables |
| D03 | Clients are **20 Nigerian organisations** across the NGO, public and private sectors, spread over **all six geopolitical zones** | Clients concentrated in Lagos; foreign clients | Each office then serves a realistic share of clients (Lagos 6, Abuja 8, Port Harcourt 6), and every sector appears in every region, so queries by sector (Portfolio 5 sharding) and by office (Q8) return meaningful groups. | `seed.sql` |
| D04 | Record money in **Nigerian naira (NGN)** | Euro or US dollar | A Nigerian consultancy budgets and invoices Nigerian clients in naira; using a foreign currency would add exchange-rate questions the case study does not need. | `budget_ngn`, `amount_ngn`, `hourly_rate_ngn` |
| D05 | Assess clients against **ISO/IEC 27001:2022, the Nigeria Data Protection Act 2023 (NDPA) and NIST CSF 2.0** | GDPR (first version); CBN Risk-Based Cybersecurity Framework; PCI DSS | ISO 27001 is the most widely used security management standard and suits every client. The NDPA is the data protection law that applies to all Nigerian clients that process personal data, and replaces GDPR in a Nigerian setting. NIST CSF 2.0 is applied to private clients as a widely used risk framework. Sector-specific frameworks (CBN, PCI DSS) would apply to only a few clients. | `framework`, `control` tables |

## 2. Platform and tools

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D06 | **PostgreSQL 16** for the relational database | MySQL 8, SQL Server, Oracle | One free DBMS covers four portfolios: partial, covering and GIN indexes and `EXPLAIN (ANALYZE, BUFFERS)` for Portfolio 2; true SERIALIZABLE isolation that detects write skew (Serializable Snapshot Isolation) for Portfolio 3; generated columns and rich constraints for Portfolio 1; declarative partitioning, `postgres_fdw` and streaming replication for Portfolio 5. MySQL has no partial indexes and no foreign-table partitions; SQL Server and Oracle need licences. | All `.sql` files |
| D07 | **MongoDB 7** for the document model | PostgreSQL JSONB, Couchbase, Cassandra | MongoDB's aggregation pipeline, array updates (`arrayFilters`), schema validation and built-in replica sets suit varied audit evidence. JSONB was seriously considered (one database fewer) and is discussed as the alternative in Portfolio 4; Cassandra is a wide-column store built for write-heavy time series, which evidence is not. | `portfolio-4-nosql/mongo/` |
| D08 | **Neo4j 5 Community** for the graph model | Recursive CTEs in PostgreSQL, ArangoDB | Attack-path questions ("what can an attacker reach in 4 hops?") are graph traversals. Cypher expresses them in one pattern; SQL needs a recursive CTE with cycle detection. Neo4j Community is free and the most widely documented graph database. | `portfolio-4-nosql/graph/` |
| D09 | **Docker Compose** to run multi-node setups | Virtual machines; paid cloud services | Seven database nodes start with one command on a laptop at no cost, and the assessor can rebuild the identical environment from the committed file. VMs are heavier to share; cloud services cost money and cannot be reproduced from the repository alone. | `docker-compose.yml` files |

## 3. Portfolio 1: schema design

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D10 | Put all tables in one schema, **`ead`** | The default `public` schema | Separates the project from other objects, and `DROP SCHEMA ... CASCADE` rebuilds everything in one statement, so every test starts from the same state. | `schema.sql` |
| D11 | **Surrogate integer keys** (SERIAL) for business entities; a **natural key** for `state`; **hand-assigned** ids for `service_line`; **composite keys** for junction tables | Natural keys everywhere (names, emails); UUIDs | Names, titles and emails change, an integer never does, and integer joins are fast. State codes (LA, FC, RI) are stable and meaningful, so a surrogate would add a join for nothing. UUIDs avoid conflicts between independent writers, but here all writes go to one primary, so their larger size buys nothing. | `schema.sql` |
| D12 | **BIGSERIAL** (64-bit) for `finding` and `audit_log`; SERIAL (32-bit) elsewhere | BIGSERIAL everywhere | Only these two tables grow without limit (every scan adds findings; every change adds an audit row). The others stay in the hundreds or thousands of rows. | `schema.sql` |
| D13 | **TEXT with CHECK** for status-like columns (`status`, `sector`, `rating`, ...) | PostgreSQL ENUM types; lookup tables | A CHECK is changed with one `ALTER TABLE`, while removing a value from an ENUM is not supported. The allowed values sit next to the column, and the error message names the rule. Lookup tables are better for values with their own attributes, which is why `state` and `service_line` are tables. | `schema.sql` |
| D14 | **NUMERIC** for money and CVSS scores | REAL or DOUBLE PRECISION; integer kobo | Exact decimals. Floating point cannot store values such as 0.1 exactly, so sums of payments could be off by fractions. Integer kobo would also be exact but less readable in reports. | `schema.sql` |
| D15 | **INET** type for IP addresses | TEXT | PostgreSQL validates the address and supports network operators (for example "all assets in 10.1.0.0/16"), which suits scan scoping. | `asset.ip_address` |
| D16 | A separate **`state`** table holding each state's zone and serving office | Store zone and office in `client` | Zone and serving office depend on the state, not on the client. Storing them in `client` would create the transitive dependency client_id -> state_code -> zone, breaking 3NF, and moving a state to another office would mean updating every client in it. | `state` table |
| D17 | **`severity` as a generated column** derived from `cvss_score` | Ordinary column set by the application; compute in every query | Severity is fully determined by the score (CVSS v3 ranges), so storing it independently breaks 3NF and allows contradictions. A generated column is derived by the database, cannot be set by hand (test T11), and can still be indexed (Q1). | `finding.severity` |
| D18 | Row-level **CHECK rules** linking columns: end date after start date; status `fixed` if and only if `fixed_on` is set | Leave to the application | These rules involve only one row, so a CHECK enforces them cheaply and for every writer. The fixed/fixed_on rule keeps the remediation-time report (Q2) correct. | `ck_engagement_dates`, `ck_finding_fixed` |
| D19 | **ON DELETE CASCADE** only for dependent rows (sites, assets, staffing, assessments, sessions, attendance); default **RESTRICT** for findings, invoices and payments | CASCADE everywhere; RESTRICT everywhere | Dependent rows have no meaning without their parent, so they go with it. Findings, invoices and payments are evidence and financial records: deleting an engagement must fail rather than silently erase them. | `schema.sql` |
| D20 | **Triggers** for rules spanning tables: asset belongs to the engagement's client; payments never exceed the invoice | Enforce in the application; no enforcement | A CHECK sees only the row being written. A trigger enforces cross-table rules inside the database, so no script or application can bypass them (tests T9 and T10). | `trg_finding_asset_client`, `trg_payment_within_invoice` |
| D21 | The payment trigger **locks the invoice row** (`SELECT ... FOR UPDATE`) before checking the total | Check without locking | Without the lock, two payments arriving at the same moment could each see the old total and both pass, overpaying the invoice. The lock makes the second payment wait for the first. | `fn_payment_within_invoice` |
| D22 | **`audit_log` with JSONB snapshots and no foreign key** | One audit table per audited table; a foreign key to the audited row | One table serves any audited table whatever its columns. The missing foreign key is deliberate: the audit trail must survive deletion of the row it describes. | `audit_log` |
| D23 | Audit **UPDATE and DELETE** on findings, not INSERT | Audit every operation | An insert is already recorded by the row itself. Skipping it keeps the 66,000-row seed load fast. | `trg_audit_finding` |
| D24 | Trigger functions **fix `search_path = ead`** | Rely on the caller's search path | The functions then work from any session (Portfolio 5 replicas and remote connections included), and an attacker cannot make them call a look-alike table in another schema (search path hijacking). | `schema.sql` |
| D25 | **Index every foreign key column** used in joins or cascades | Rely on automatic indexes | PostgreSQL indexes primary keys and UNIQUE columns automatically but not foreign keys. Without these indexes, joins and cascaded deletes scan whole tables. | `schema.sql` |
| D26 | A **view `v_open_findings`** for the triage join | Repeat the join in each query | The five-table join is needed by several reports. Writing it once prevents copies that drift apart. | `schema.sql`, Q1 |
| D27 | Store training participants as an **email in `attendance`**, not a person table | A full participant table | Participants are client staff, identified only for attendance. Storing the minimum applies the NDPA's data minimisation principle (section 24). | `attendance` |
| D28 | **Payments in their own table** | A `paid` flag or amount column on `invoice` | One invoice can be paid in several instalments (Portfolio 3, scenario 2), so payments are a one-to-many child. | `payment` |

## 4. Portfolio 1: sample data

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D29 | **Synthetic data** with fictitious names, hosts and IP addresses; **real public CVE identifiers** | Real client data; fully invented vulnerabilities | Real client data would breach confidentiality and the NDPA. Real CVEs (Log4Shell, BlueKeep, ...) make the findings realistic and searchable without exposing anyone. | `seed.sql` |
| D30 | **Fixed random seed** (`setseed(0.42)`) | Different random data on each run | Everyone who runs the scripts gets the same rows, so query results, timings and screenshots can be compared and reproduced. | `seed.sql` |
| D31 | About **66,000 findings**, but small reference tables (2,340 assessments, 60 engagements) | Small tables everywhere; millions of rows | At 66,000 rows the planner's choice between a full scan and an index becomes visible in Portfolio 2, while the load still takes seconds on a laptop. Keeping `control_assessment` small is deliberate: it gives Q3 an honest case where an index does not help. | `seed.sql` |
| D32 | Each client's **data-centre site is in the city of its serving office** | Random cities | Colocation facilities are in Lagos, Abuja and Port Harcourt (D02), so a client served from Abuja realistically hosts there. | `seed.sql` |
| D33 | **Illustrative rates and budgets**: hourly rates from NGN 48,000 (analyst) to NGN 84,000 (manager); budgets NGN 10.5m to 32.4m | Market-researched figures | The figures are illustrative, not market data. They were set so that some engagements exceed their budget, which gives the budget-risk query (Q5) something to flag. | `seed.sql` |

## 5. Portfolio 2: queries and optimisation

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D34 | **Nine queries, each answering a real business question and each showing a different SQL feature** | Generic textbook queries | The rubric rewards technical correctness and analysis; queries tied to TerraCyb's work (triage, remediation time, compliance, budget, exposure) show the database serving its purpose, and the spread of features (joins, CTEs, window functions, ROLLUP, full-text search) avoids repetition. | `queries/` |
| D35 | Q1: **partial index** on `found_on` covering only open or in-progress critical findings | Full index on (status, severity, found_on) | The query always asks for the same small slice of the table. A partial index holds only those rows, already sorted, so it is small and lets the planner stop after 50 rows. | `indexes.sql` |
| D36 | Q2: **materialised view** | An index | The query aggregates most of the table; no index avoids reading those rows. Precomputing the result is the only large gain. Accepted trade-off: the data is only as fresh as the last refresh, which suits a quarterly management report. | `indexes.sql`, `q2b_...sql` |
| D37 | Q3, Q5 and Q6a: **deliberately no new index** | Index everything | Showing when an index does **not** help is part of performance analysis: Q3 and Q5 read small tables almost entirely, and `ILIKE '%password%'` cannot use a B-tree. Over-indexing also slows every write. | `README.md` section 4 |
| D38 | Q4: **covering partial index** `(asset_id) INCLUDE (cvss_score)` on unresolved findings | Plain index on `asset_id` | The query needs only these two columns of unresolved rows. INCLUDE allows an index-only scan that never reads the table. | `indexes.sql` |
| D39 | Q6b: **GIN index on `to_tsvector('english', title)`** | Trigram index (`pg_trgm`) | Full-text search matches word forms ("passwords" finds "password") and the GIN index makes it fast. The trigram option is left as an extension to compare. | `indexes.sql` |
| D40 | Q7: **partial B-tree on `cve_id` where it is not null** | Full B-tree on `cve_id` | Most findings have no CVE; excluding them keeps the index small while serving every CVE lookup. | `indexes.sql` |
| D41 | Q8: **no new index; reuse Q4's index** | A dedicated index | One well-chosen index serving several queries is cheaper to maintain than one index per query. | `README.md` |
| D42 | Benchmark: **median of 5 runs, warm cache, `EXPLAIN (ANALYZE, BUFFERS)`**, indexes dropped then recreated by script | Single run; cold cache | A single run is distorted by whatever else the laptop is doing; the median resists outliers. Cold-cache timings depend on the operating system's file cache and are hard to reproduce. Scripting the drop and recreate guarantees a fair before/after comparison. | `run_benchmark.sh` |
| D43 | Compare join algorithms by **switching planner options** (`enable_hashjoin`, `enable_mergejoin`) | Only show the default plan | Running the same query with different join methods isolates the effect of the join algorithm alone. | `join_strategies.sql` |

## 6. Portfolio 3: transactions and concurrency

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D44 | **Five scenarios mapped to the brief**: commit, rollback with savepoint, lost update, isolation levels, deadlock | Fewer, generic scenarios | The brief names commit, rollback, isolation and a concurrency issue or control mechanism; each scenario evidences one of them using TerraCyb operations (closing a finding, recording a payment, allocating hours, a compliance report). | `01` to `05` scripts |
| D45 | Run concurrency scenarios as **two scripted sessions with `pg_sleep`** | Manual two-terminal runs only | Timed pauses force the same interleaving on every run, so the logs are reproducible evidence. Manual runs remain for the screenshots the brief asks for (README section 5). | `03`, `04`, `05` scripts |
| D46 | Fix the lost update with **`SELECT ... FOR UPDATE`** | Atomic update (`hours = hours + 5`); optimistic locking with a version column | The scenario is read, decide, then write: a manager looks at the hours before deciding. A row lock protects exactly that pattern. The atomic update is mentioned as a valid alternative when no decision is needed. Optimistic locking suits long user think-times, which this is not. | `03_lost_update.sh` |
| D47 | Prevent write skew with **SERIALIZABLE** isolation | Explicit locks on all affected rows | Write skew happens when transactions update **different** rows, so ordinary row locks never conflict. SERIALIZABLE detects the dangerous pattern without the developer knowing which rows to lock. Cost: the application must retry on SQLSTATE 40001, which the README states. | `04_isolation_levels.sh` |
| D48 | Demonstrate a deadlock and its **prevention by ordered locking** | Skip deadlocks | Deadlocks are a real risk once row locks are used (D46). Showing detection, and the rule "always lock rows in the same order", completes the concurrency picture. | `05_deadlock.sh` |
| D49 | Scripts **restore the rows they change** | Leave changes in place | Scenarios can be rerun in any order with the same results. | `03` to `05` scripts |

## 7. Portfolio 4: NoSQL models

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D50 | Model **audit evidence as documents** | More relational tables | Scans, policy documents, firewall configurations and interview notes have different structures. In SQL that means many sparse tables or untyped blobs; one document per item fits each shape. | `mongo/` |
| D51 | **Embed scan results** inside the scan document; **reference** engagements and clients by id | Separate results collection; copy client details | Results are always read with their scan and belong to no other document, so embedding avoids joins. Engagement and client data change and live in PostgreSQL, so copying them would create stale duplicates. | `02_load_evidence.js` |
| D52 | **Validate only the fields every evidence type shares** (`$jsonSchema`) | No validation; full validation of every type | Shared fields must be consistent for queries to work; type-specific fields stay flexible, which is the point of the document model. | `01_create_collection.js` |
| D53 | **3,000 generated scan documents** in addition to 6 hand-written examples | Only the examples | Index effects (collection scan vs index scan) are invisible on six documents. | `02_load_evidence.js` |
| D54 | **Hostnames and IP addresses exported from PostgreSQL** into MongoDB and Neo4j | Invent separate data | All three stores then describe the same assets, which a real polyglot system requires. | `export_assets.sh`, `assets.json` |
| D55 | Indexes: **compound** (engagement, control), **multikey** (`results.cve`), **text** | Index only `_id` | Each matches a real access path: evidence per engagement and control, CVE lookups inside arrays, and keyword search. | `03_queries.js` |
| D56 | Graph of **one client (13 assets, 4 CVEs, 12 links)** | Load all 850 assets | Network links are not in the relational data and are modelled by hand; one client is enough to show multi-hop paths, shortest paths and choke points while staying readable in the Neo4j Browser. | `01_create_graph.cypher` |
| D57 | Attack paths start from **internet-facing assets with CVSS 9 or more** | Any vulnerable asset | CVSS 9.0 is the start of the "critical" range used for `severity` (D17), and internet exposure is what makes an asset a realistic entry point. | `02_attack_paths.cypher` |

## 8. Portfolio 5: distribution and siting

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D58 | **Lagos is the primary** (all writes) | Abuja as primary | Lagos has 21 of Nigeria's 28 data centres, most subsea cables and the largest client market (D02). | `docker-compose.yml` |
| D59 | **Port Harcourt is the disaster-recovery standby** | Abuja as standby | Port Harcourt has the only international subsea route that does not pass through Lagos (2Africa), so a cut to the Lagos cables does not isolate both sites. It is 448 km away, outside a Lagos-wide disaster. | `docker-compose.yml`, `replica-entrypoint.sh` |
| D60 | **Abuja holds public-sector clients' findings** | Abuja as a second full copy | NITDA's cloud policy emphasises sovereign hosting of government data; Abuja has a Tier III government data centre, the federal clients and the regulators. | `geo_sharding.sql`, `abuja_node_init.sql` |
| D61 | **Shard key = client sector**, not region | Shard by geopolitical zone | All nodes are in Nigeria, so the NDPA (which regulates transfers abroad, sections 41 to 43) does not require a regional split. The rules that care where data sits are sector rules: government data and, from 1 January 2027, CBN-regulated payment data. | `geo_sharding.sql` |
| D62 | Implement sharding with **declarative partitioning plus `postgres_fdw`** | Citus extension; application-level sharding | Both features are built into PostgreSQL, so no extra software is needed, and the effect (partition pruning, remote SQL) is visible in standard `EXPLAIN` output. Citus would be the production choice at large scale. | `geo_sharding.sql` |
| D63 | Copy `sector` and `office_code` into `finding_geo` | Keep them only in `client` and `state` | A partition key must be a column of the partitioned table. This is a deliberate, documented denormalisation. | `geo_sharding.sql` |
| D64 | **Asynchronous replication by default; synchronous recommended for billing** | Synchronous for everything | Asynchronous keeps writes fast, and a dashboard a few seconds stale is acceptable. Payments must never be lost, which justifies the extra latency of synchronous commits for billing (README section 5.5). | `README.md` 5.5 |
| D65 | Use a **replication slot** (`replica1`) | Rely on `wal_keep_size` alone | The slot makes Lagos keep every WAL record Port Harcourt still needs, so the standby can catch up after an outage. Risk: WAL piles up if the standby stays down for long, so slot lag must be monitored (shown by `replication_status_primary.sql`). | `primary-init.sh` |
| D66 | **Manual promotion** (`pg_promote()`) | Automatic failover with Patroni | Manual promotion shows each failover step clearly and needs no extra components. Patroni is named as the production choice. | `replication_failover_demo.sh` |
| D67 | **One MongoDB member per site; Lagos has priority 2** | Three members in Lagos | One member per city means losing any one site still leaves a majority (2 of 3), so the set keeps accepting writes. The priority makes headquarters the normal primary. | `init-replica-set.sh` |
| D68 | Evidence writes use **`w: "majority"`** | `w: 1`; `w: 3` | `w: 1` can lose a write in a failover; `w: 3` stops all uploads when one site is down. Majority survives any one site failure while staying available. | `replica-set-demo.js` |

## 9. Evidence and working method

| ID | Decision | Alternatives considered | Reason | Where |
| --- | --- | --- | --- | --- |
| D69 | **Test-run outputs and screenshots are committed, each labelled with how and when it was captured** (all five portfolios run in GitHub Codespaces on 15 November 2026 and captured as screenshots of the screen) | Leave outputs out until the scripts are run; outputs rendered from captured text; unlabelled screenshots | The brief asks for screenshots and outputs as evidence. Running every portfolio myself and capturing the real screen gives the strongest evidence and lets me explain each result. Every screenshot shows the exact command and its unedited output, and the captions state the capture conditions, including the first lock-demo attempt in which B started too late to wait and the harmless psql warnings in Portfolio 5. | `screenshots/` and `output/` folders; captions |
| D70 | **Commits use their real dates** | Backdated commits | The brief uses progressive commit history as evidence; it must reflect when work actually happened. | Git history |
| D71 | **Comments state the reason for each choice**, not only what the code does | Minimal comments | The brief may select students for technical verification; reasons written next to the code make every decision explainable. | All code files |
