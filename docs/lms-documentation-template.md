# LMS Documentation Template (2-3 pages)

Copy this into Word or Google Docs, fill every _italic_ placeholder with your own results and words, and export as PDF for the LMS. Keep it to 2-3 pages: one short paragraph and one screenshot per portfolio is enough.

---

## MIT 8103 Advanced Database Systems: Portfolio Documentation

**Student:** Osita Kingsley Odo
**GitHub repository:** _https://github.com/<your-username>/terracyber-advanced-database-portfolio_ (private; assessor added as collaborator on _date_)

### 1. Selected organisation

TerraCyber Consulting is a multi-site cybersecurity consultancy serving NGOs, public bodies and private firms in three service lines: compliance and data protection, advisory and resilience, and training and security awareness. Its Engagement and Assurance Database (EAD) is used by consultants, engagement managers, trainers, finance staff and auditors. It stores clients and sites, engagements, assets, vulnerability findings, compliance controls and assessments, audit evidence, training records, invoices and payments. Key operations: _list the 4-5 most important_.

### 2. Portfolio 1: Database design and modelling

_2-3 sentences: 17 tables in 3NF, the two junction tables, the most interesting constraints (generated severity column, cross-table triggers), and the constraint test result (11 of 11 rejected)._

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

_2-3 sentences: streaming replica, geo-sharding of African clients' findings to a separate node, failover by promotion (time: X s), MongoDB automatic election, and your CAP choice for invoices vs evidence._

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
- Regulation (EU) 2016/679 (General Data Protection Regulation).
- _Add your course textbook and any other sources you used._

### 9. AI-use declaration

_Copy the completed declaration from the root README._
