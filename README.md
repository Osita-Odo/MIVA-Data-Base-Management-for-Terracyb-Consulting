# Advanced Database Systems Portfolio: TerraCyber Consulting

**Course:** MIT 8103 Advanced Database Systems, MIVA Open University, 2026/2027 First Semester
**Student:** Osita Kingsley Odo
**Assessment:** Individual Practical Database Portfolio (40 marks)

## Selected organisation (case study statement)

| Item | Description |
| --- | --- |
| **Organisation** | TerraCyber Consulting ([terracybconsulting.com](https://terracybconsulting.com)), a Nigerian cybersecurity consultancy delivering grounded, human-centred cybersecurity |
| **Locations** | Three sites: **Lagos** (headquarters, primary database), **Abuja** (northern office, public-sector data shard) and **Port Harcourt** (South South and South East office, disaster-recovery standby). The choice of sites is justified in [docs/site-selection.md](docs/site-selection.md). |
| **Nature of the business** | Consultancy for NGOs, public sector bodies and private firms in all six geopolitical zones of Nigeria, across three service lines: compliance and data protection; advisory and resilience; training and security awareness |
| **Database** | Engagement and Assurance Database (EAD) |
| **Users** | Consultants and analysts, engagement managers, trainers, finance staff, auditors (read-only), client contacts (read-only portal) |
| **Major data** | Offices, the 36 states and FCT with their serving office, consultants, clients and their sites, engagements and staffing, client assets, vulnerability findings, compliance frameworks and controls, control assessments, audit evidence, training sessions and attendance, invoices and payments, audit trail |
| **Key operations** | Open and staff an engagement; log and triage findings; assess controls against ISO/IEC 27001, the Nigeria Data Protection Act 2023 (NDPA) or NIST CSF 2.0; attach evidence; track remediation; deliver training and record results; invoice in naira and record payments; produce client compliance reports |

All data in this repository is synthetic. Names, organisations, hostnames and IP addresses are fictitious; CVE identifiers are real public vulnerabilities used as examples.

## Repository structure

```
terracyber-advanced-database-portfolio/
├── portfolio-1-database-design/          ER model, schema, constraints, normalisation, seed data
├── portfolio-2-query-optimisation/       9 queries, execution plans, indexes, benchmark
├── portfolio-3-transactions-concurrency/ commit, rollback, locking, isolation levels, deadlock
├── portfolio-4-nosql/                    MongoDB document model and Neo4j graph model
├── portfolio-5-distributed-cloud/        Lagos primary, Port Harcourt standby, Abuja shard, failover
├── docs/                                 design decisions, site selection, LMS template
└── README.md                             this file
```

| Portfolio | Marks | Main evidence | README |
| --- | --- | --- | --- |
| 1. Database design and modelling | 7 | ER diagram, 18-table schema, 12 constraint tests, normalisation walk-through | [link](portfolio-1-database-design/README.md) |
| 2. Query processing and optimisation | 7 | Query results, before/after plans, timing table | [link](portfolio-2-query-optimisation/README.md) |
| 3. Transactions and concurrency | 7 | Logs of 5 scenarios, two-terminal screenshots | [link](portfolio-3-transactions-concurrency/README.md) |
| 4. NoSQL and advanced data models | 7 | MongoDB outputs, Neo4j attack paths, suitability analysis | [link](portfolio-4-nosql/README.md) |
| 5. Distributed and cloud database | 6 | Replication (Lagos to Port Harcourt), sharding (Abuja) and failover logs | [link](portfolio-5-distributed-cloud/README.md) |
| Final documentation | 6 | 2-3 page LMS document | [docs](docs/lms-documentation-template.md) |

## Design decisions

Every significant choice in this project, from the three sites to individual column types and index choices, is recorded with the alternatives considered and the reason for the decision:

- [docs/design-decisions.md](docs/design-decisions.md): register of 71 decisions (D01 to D71), referenced from the code comments and each portfolio README
- [docs/site-selection.md](docs/site-selection.md): evidence and weighted scoring behind the choice of Lagos, Abuja and Port Harcourt

## Technology stack

| Tool | Version | Used in |
| --- | --- | --- |
| PostgreSQL | 16 | Portfolios 1, 2, 3, 5 |
| MongoDB | 7.0 | Portfolios 4, 5 |
| Neo4j Community | 5 | Portfolio 4 |
| Docker and Docker Compose | current | Portfolios 4, 5 |
| dbdiagram.io | web | ER diagram export |
| psql, mongosh, cypher-shell | bundled | All scripts |

## Quick start

```bash
# Portfolios 1 to 3 need a local PostgreSQL 16
createdb ead
psql -d ead -f portfolio-1-database-design/schema.sql
psql -d ead -f portfolio-1-database-design/seed.sql

cd portfolio-2-query-optimisation && ./run_queries.sh && ./run_benchmark.sh && cd ..
cd portfolio-3-transactions-concurrency && ./run_all.sh && cd ..

# Portfolios 4 and 5 run in Docker
cd portfolio-4-nosql && docker compose up -d && cd ..
cd portfolio-5-distributed-cloud && docker compose up -d && cd ..
```

Each portfolio README gives the full steps, the expected output and an evidence checklist. Stop the Portfolio 4 stack before starting Portfolio 5 if port 5432 is already used by a local PostgreSQL; or change the host port in `portfolio-5-distributed-cloud/docker-compose.yml`.

## Progress log

The brief rewards progressive commits. Record each milestone when it is committed.

| Date | Portfolio | Work committed |
| --- | --- | --- |
| | 1 | Case study statement, ER diagram, schema |
| | 1 | Seed data, constraint tests, normalisation write-up |
| | 2 | Queries and baseline plans |
| | 2 | Indexes, after plans, performance analysis |
| | 3 | Transaction scenarios, logs and screenshots |
| | 4 | MongoDB model, queries and indexes |
| | 4 | Neo4j graph and suitability analysis |
| | 5 | Replication and failover |
| | 5 | Geo-sharding and consistency analysis |
| | Final | LMS documentation and reflection |

## AI-use declaration

AI tools were used as a learning aid, as permitted by section 7 of the assessment brief.

| Item | Detail |
| --- | --- |
| Tool | Claude (Anthropic) |
| Used for | _Describe honestly, for example: planning the case study scope, drafting an initial version of scripts and README structure, explaining concepts._ |
| My own work | _Describe what you ran, tested, changed, measured and wrote yourself, for example: ran every script on my machine, captured all outputs and screenshots, wrote the analysis and reflection, changed X and Y._ |
| Verification | _How you checked correctness, for example: executed all SQL on PostgreSQL 16, compared plans, repeated the concurrency tests in two terminals._ |

I understand every design decision in this repository and can explain it if selected for technical verification.
