# Portfolio 4: NoSQL and Advanced Data Models

**Case study:** TerraCyber Consulting EAD
**Technologies:** MongoDB 7 (document model), Neo4j 5 (graph model)
**Marks:** 7

## 1. What this portfolio delivers

| Evidence required by the brief | Where it is |
| --- | --- |
| NoSQL model based on the same case study | Section 2: audit evidence as documents, network exposure as a graph |
| Document example | [`mongo/`](mongo): collection with a `$jsonSchema` validator, 3,006 documents, queries, aggregation, indexes |
| Graph example | [`graph/`](graph): assets, vulnerabilities and network paths in Neo4j |
| Implementation evidence | `evidence-samples/*.txt` outputs and screenshots (section 4) |
| Explanation of suitability | Section 5 |

## 2. Why NoSQL here: polyglot persistence

PostgreSQL stays the **system of record** for engagements, findings, controls and money. Two kinds of TerraCyber data fit it badly:

1. **Audit evidence.** A vulnerability scan, a policy PDF's metadata, a firewall configuration and an interview note have completely different structures. In SQL this needs many sparse tables or an untyped blob.
2. **Network exposure.** "Can an attacker get from this internet-facing server to the finance database?" is a path question over many hops.

The two stores link back to PostgreSQL through shared keys: every evidence document carries `engagement_id` and `client_id`. Hostnames and IP addresses in both MongoDB and Neo4j are exported from the PostgreSQL `asset` table (`mongo/export_assets.sh`).

## 3. Models

### 3.1 Document model (MongoDB), collection `evidence`

One document per piece of evidence. Shared fields are validated; type-specific fields are free.

| Field | All types | Only some types |
| --- | --- | --- |
| `_id` (`EV-YYYY-NNNNN`), `engagement_id`, `client_id`, `control_ref`, `type`, `collected_by`, `collected_at`, `tags[]` | Yes | |
| `scanner{}`, `results[]` (host, ip, port, cve, cvss, status) | | `vuln_scan` |
| `document{}`, `review{}` | | `policy_document` |
| `device{}`, `firewall_rules[]`, `issues[]` | | `config_snapshot` |
| `questions[]`, `conclusion` | | `interview_note` |
| `image{}`, `caption` | | `screenshot` |

**Design decisions:**

- Scan results are **embedded** in the scan document. They are always read with their scan and never shared, and one document stays far below MongoDB's 16 MB limit.
- Engagement and client details are **referenced** by id, not copied. They change and they live in PostgreSQL.
- A `$jsonSchema` validator rejects documents with an unknown `type` or a CVSS outside 0 to 10. That is schema-on-write for what must be consistent, and flexibility for the rest.

Example (shortened):

```json
{
  "_id": "EV-2026-00001",
  "engagement_id": 1,
  "client_id": 1,
  "control_ref": "ISO27001:A.8.8",
  "type": "vuln_scan",
  "collected_by": "consultant18",
  "collected_at": "2026-03-02T09:14:00Z",
  "scanner": { "name": "OpenVAS", "version": "23.1" },
  "results": [
    { "host": "lagoon-1-010", "ip": "10.1.0.11", "port": 443,
      "cve": "CVE-2021-44228", "cvss": 10.0, "status": "open" }
  ],
  "tags": ["perimeter", "external-scan"]
}
```

### 3.2 Graph model (Neo4j)

```mermaid
graph LR
    C[Client] -- HAS_SITE --> S[Site]
    S -- HOSTS --> A[Asset]
    A -- CONNECTS_TO --> A2[Asset]
    A -- AFFECTED_BY --> V[Vulnerability]
```

| Node | Properties |
| --- | --- |
| `Client` | client_id, name, sector |
| `Site` | site_id, name |
| `Asset` | hostname (unique), ip, asset_type, criticality, internet_facing |
| `Vulnerability` | cve (unique), name, cvss |

The graph covers client 1 (Lagoon Community Food Network, an NGO with a head office and a data-centre site in Lagos): 13 assets, 4 CVEs, 12 network links.

## 4. How to run

```bash
docker compose up -d

# MongoDB
./mongo/export_assets.sh                       # needs the Portfolio 1 database; assets.json is already committed
docker exec -it tc-mongo mongosh terracyber /scripts/01_create_collection.js
docker exec -it tc-mongo mongosh terracyber /scripts/02_load_evidence.js
docker exec -it tc-mongo mongosh terracyber /scripts/03_queries.js > evidence-samples/mongo-output.txt

# Neo4j
docker exec tc-neo4j cypher-shell -u neo4j -p terracyber-demo -f /scripts/01_create_graph.cypher
docker exec tc-neo4j cypher-shell -u neo4j -p terracyber-demo -f /scripts/02_attack_paths.cypher > evidence-samples/neo4j-output.txt
```

Open http://localhost:7474 and run `MATCH (n) RETURN n` to see the graph. Screenshot it for the LMS.

### MongoDB operations (`03_queries.js`)

| # | Operation | Feature |
| --- | --- | --- |
| Q1 | Evidence for one engagement and control, newest first | find, projection, sort, limit |
| Q2 | Scans with an open RDP result scoring 8 or more | `$elemMatch` inside an array |
| Q3 | Top 10 hosts by open high or critical results | Aggregation: `$unwind`, `$group`, `$addToSet`, `$sort` |
| Q4 | Evidence coverage per control | Aggregation by control and type |
| Q5 | Mark Log4Shell results as fixed | `updateMany` with `arrayFilters` |
| Indexes | Compound, multikey (`results.cve`) and text indexes | `explain("executionStats")` before and after |

The script prints the plan stages and `docsExamined` before and after indexing. Before: `COLLSCAN`, all 3,006 documents examined. After: `IXSCAN`, only matching documents examined.

### Neo4j queries (`02_attack_paths.cypher`)

| # | Question |
| --- | --- |
| G1 | Every path from an exploitable internet-facing asset to a critical asset, within 4 hops |
| G2 | Shortest path from each entry point to cloud asset `lagoon-2-009` in the Lagos data centre |
| G3 | Blast radius: assets reachable within 3 hops of each entry point |
| G4 | Choke points: internal assets on the most attack paths (best places to segment) |

## 5. Suitability: which model for which job

| Need | Relational (PostgreSQL) | Document (MongoDB) | Graph (Neo4j) |
| --- | --- | --- | --- |
| Engagements, invoices, payments | **Best:** joins, constraints, ACID across tables | Weak: no cross-document constraints | Not suitable |
| Evidence with varying structure | Many sparse tables or JSONB | **Best:** one flexible document per item, validated core | Not suitable |
| Nested scan results | Child table, join on every read | **Best:** embedded and read in one go | Possible, but heavy |
| Multi-hop network paths | Recursive CTE; slows as hops grow | `$graphLookup` exists but is limited | **Best:** variable-length paths, shortest path |
| Horizontal scale for large scan volumes | Harder (see Portfolio 5) | Built-in sharding | Clustering in Enterprise edition |

**Graph vs SQL for G1.** In SQL, G1 needs a recursive CTE that joins an `asset_link` table to itself once per hop, with cycle detection. In Cypher it is one pattern: `(entry)-[:CONNECTS_TO*1..4]->(target)`. The graph engine follows stored relationships directly (index-free adjacency). It does not search a join index at each step.

**PostgreSQL JSONB as an alternative.** PostgreSQL could store evidence in a `JSONB` column with a GIN index. That would avoid a second database. MongoDB still wins here for aggregation pipelines over arrays, built-in sharding, and partial updates such as `arrayFilters`. Mention this trade-off in your reflection.

## 6. Evidence checklist

- [ ] `evidence-samples/mongo-output.txt`, including the validator rejection and before/after explain summaries
- [ ] `evidence-samples/neo4j-output.txt`
- [ ] Screenshot of MongoDB Compass or mongosh showing a scan document
- [ ] Screenshot of the Neo4j Browser graph, ideally the G1 paths highlighted
