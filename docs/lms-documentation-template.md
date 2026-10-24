# LMS Documentation Template (2-3 pages)

Copy this into Word or Google Docs, fill every _italic_ placeholder with your own results and words, and export as PDF for the LMS. Keep it to 2-3 pages: one short paragraph and one screenshot per portfolio is enough.

---

## MIT 8103 Advanced Database Systems: Portfolio Documentation

**Student:** Osita Kingsley Odo
**GitHub repository:** _https://github.com/<your-username>/terracyber-advanced-database-portfolio_ (private; assessor added as collaborator on _date_)

### 1. Selected organisation

TerraCyber Consulting is a Nigerian cybersecurity consultancy serving NGOs, public bodies and private firms in all six geopolitical zones, in three service lines: compliance and data protection, advisory and resilience, and training and security awareness. It operates from Lagos (headquarters), Abuja and Port Harcourt, chosen through a weighted siting analysis of data centres, subsea connectivity, client demand, regulator proximity, security, disaster-recovery distance and flood risk (docs/site-selection.md). Its Engagement and Assurance Database (EAD) is used by consultants, engagement managers, trainers, finance staff and auditors. It stores clients and sites, engagements, assets, vulnerability findings, compliance assessments against ISO/IEC 27001, the NDPA 2023 and NIST CSF 2.0, audit evidence, training records, and invoices and payments in naira. Key operations: _list the 4-5 most important_.

### 2. Portfolio 1: Database design and modelling

_2-3 sentences: 18 tables in 3NF (including the state table that removes the client -> state -> zone dependency), the two junction tables, the most interesting constraints (generated severity column, cross-table triggers), and the constraint test result (12 of 12 rejected)._

_Screenshot: ER diagram (erd.png)._

### 3. Portfolio 2: Query processing and optimisation

_2-3 sentences with your own numbers: best improvement (for example Q1 from X ms to Y ms with a partial index), the materialised view result, and one case where an index did not help and why._

_Screenshot: Q1 plan before and after, or results/timings.md._

### 4. Portfolio 3: Transactions and concurrency

_2-3 sentences: commit and rollback with savepoint, the lost update (110 instead of 115) fixed with FOR UPDATE, write skew prevented by SERIALIZABLE, deadlock detected._

_Screenshot: two terminals showing the lock wait, or the serialisation error._

### 5. Portfolio 4: NoSQL and advanced data models

_2-3 sentences: why evidence suits documents (varying structure, embedded scan results, validator), the index result from explain (COLLSCAN to IXSCAN, docs examined X to Y), and the Neo4j attack-path finding._

_Screenshot: Neo4j graph or a MongoDB document._

### 6. Portfolio 5: Distributed and cloud database

_2-3 sentences: Lagos primary streaming to a Port Harcourt standby (independent subsea route, 448 km away), public-sector findings sharded to Abuja, failover by promotion (time: X s), MongoDB election with one member per city, and your CAP choice for invoices vs evidence._

_Screenshot: docker compose ps or the promotion output._

### 7. Individual technical reflection

_Write this yourself, in the first person, 150-250 words. Prompts:_

- _Which design decision would you defend most strongly, and why?_
- _What went wrong while running the scripts, and how did you fix it?_
- _What surprised you in the execution plans?_
- _What would you change if TerraCyber had 100 times more data or a new office in another region?_
- _How does this connect to your cybersecurity work (audit evidence, data residency, least privilege)?_

### 8. References

- PostgreSQL Global Development Group. _PostgreSQL 16 Documentation._ https://www.postgresql.org/docs/16/
- MongoDB, Inc. _MongoDB Manual._ https://www.mongodb.com/docs/manual/
- Neo4j, Inc. _Cypher Manual._ https://neo4j.com/docs/cypher-manual/current/
- ISO/IEC 27001:2022. _Information security, cybersecurity and privacy protection: Information security management systems: Requirements._
- NIST (2024). _The NIST Cybersecurity Framework (CSF) 2.0._ https://doi.org/10.6028/NIST.CSWP.29
- Federal Republic of Nigeria (2023). _Nigeria Data Protection Act, 2023._
- Nigeria Data Protection Commission (2025). _NDPA General Application and Implementation Directive (GAID) 2025._
- Sources on data centres, connectivity, flood risk and security are listed in docs/site-selection.md.
- _Add your course textbook and any other sources you used._

### 9. AI-use declaration

_Copy the completed declaration from the root README._
