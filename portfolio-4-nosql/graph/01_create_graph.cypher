// =====================================================================
// Portfolio 4 / Neo4j step 1: attack-surface graph for one client
// Client 1 (Lagoon Community Food Network, Lagos). Hostnames, IPs, asset types and
// criticality match the PostgreSQL seed data. CONNECTS_TO edges model
// network reachability observed during the engagement.
// Why one client only (D56): network links are not in the relational data
// and are modelled by hand; 13 assets are enough to show multi-hop paths
// while staying readable in the Neo4j Browser.
// Run: docker exec -i tc-neo4j cypher-shell -u neo4j -p terracyb-demo < graph/01_create_graph.cypher
// =====================================================================

MATCH (n) DETACH DELETE n;

CREATE CONSTRAINT asset_host IF NOT EXISTS FOR (a:Asset) REQUIRE a.hostname IS UNIQUE;
CREATE CONSTRAINT vuln_cve   IF NOT EXISTS FOR (v:Vulnerability) REQUIRE v.cve IS UNIQUE;

// ---------- Client and sites ----------
CREATE (c:Client {client_id: 1, name: 'Lagoon Community Food Network', sector: 'ngo', state: 'Lagos'})
CREATE (ho:Site {site_id: 1, name: 'Head office', city: 'Lagos'})
CREATE (dc:Site {site_id: 2, name: 'Data centre', city: 'Lagos'})
CREATE (c)-[:HAS_SITE]->(ho)
CREATE (c)-[:HAS_SITE]->(dc);

// ---------- Assets ----------
UNWIND [
  {h: 'lagoon-1-001', ip: '10.1.0.2',  type: 'workstation', crit: 'critical', inet: true,  site: 1},
  {h: 'lagoon-1-002', ip: '10.1.0.3',  type: 'network',     crit: 'medium',   inet: false, site: 1},
  {h: 'lagoon-1-003', ip: '10.1.0.4',  type: 'network',     crit: 'low',      inet: true,  site: 1},
  {h: 'lagoon-1-007', ip: '10.1.0.8',  type: 'workstation', crit: 'critical', inet: true,  site: 1},
  {h: 'lagoon-1-008', ip: '10.1.0.9',  type: 'server',      crit: 'low',      inet: false, site: 1},
  {h: 'lagoon-1-009', ip: '10.1.0.10', type: 'server',      crit: 'medium',   inet: false, site: 1},
  {h: 'lagoon-1-010', ip: '10.1.0.11', type: 'application', crit: 'critical', inet: true,  site: 1},
  {h: 'lagoon-2-003', ip: '10.2.0.4',  type: 'server',      crit: 'low',      inet: true,  site: 2},
  {h: 'lagoon-2-006', ip: '10.2.0.7',  type: 'network',     crit: 'low',      inet: false, site: 2},
  {h: 'lagoon-2-009', ip: '10.2.0.10', type: 'cloud',       crit: 'critical', inet: true,  site: 2},
  {h: 'lagoon-2-012', ip: '10.2.0.13', type: 'application', crit: 'critical', inet: false, site: 2},
  {h: 'lagoon-2-014', ip: '10.2.0.15', type: 'network',     crit: 'low',      inet: false, site: 2},
  {h: 'lagoon-2-016', ip: '10.2.0.17', type: 'server',      crit: 'critical', inet: false, site: 2}
] AS row
MATCH (s:Site {site_id: row.site})
CREATE (a:Asset {hostname: row.h, ip: row.ip, asset_type: row.type,
                 criticality: row.crit, internet_facing: row.inet})
CREATE (s)-[:HOSTS]->(a);

// ---------- Vulnerabilities (public CVEs) ----------
UNWIND [
  {cve: 'CVE-2021-44228', name: 'Log4Shell',                     cvss: 10.0},
  {cve: 'CVE-2024-3400',  name: 'PAN-OS GlobalProtect injection', cvss: 10.0},
  {cve: 'CVE-2019-0708',  name: 'BlueKeep',                      cvss: 9.8},
  {cve: 'CVE-2021-34527', name: 'PrintNightmare',                cvss: 8.8}
] AS v
CREATE (:Vulnerability {cve: v.cve, name: v.name, cvss: v.cvss});

UNWIND [
  {h: 'lagoon-1-010',  cve: 'CVE-2021-44228'},
  {h: 'lagoon-1-003',  cve: 'CVE-2024-3400'},
  {h: 'lagoon-1-007',  cve: 'CVE-2019-0708'},
  {h: 'lagoon-2-003', cve: 'CVE-2021-34527'}
] AS row
MATCH (a:Asset {hostname: row.h}), (v:Vulnerability {cve: row.cve})
CREATE (a)-[:AFFECTED_BY {status: 'open', engagement_id: 21}]->(v);

// ---------- Network reachability ----------
UNWIND [
  {f: 'lagoon-1-003',  t: 'lagoon-1-002',  port: 'any'},
  {f: 'lagoon-1-002',  t: 'lagoon-1-001',  port: 'any'},
  {f: 'lagoon-1-002',  t: 'lagoon-1-008',  port: '445'},
  {f: 'lagoon-1-002',  t: 'lagoon-1-009',  port: '5432'},
  {f: 'lagoon-1-007',  t: 'lagoon-1-002',  port: 'any'},
  {f: 'lagoon-1-010',  t: 'lagoon-1-009',  port: '5432'},
  {f: 'lagoon-1-009',  t: 'lagoon-2-014', port: 'any'},
  {f: 'lagoon-2-003', t: 'lagoon-2-014', port: 'any'},
  {f: 'lagoon-2-014', t: 'lagoon-2-012', port: '443'},
  {f: 'lagoon-2-014', t: 'lagoon-2-006', port: '22'},
  {f: 'lagoon-2-006', t: 'lagoon-2-009', port: '443'},
  {f: 'lagoon-2-006', t: 'lagoon-2-016', port: '443'}
] AS e
MATCH (a:Asset {hostname: e.f}), (b:Asset {hostname: e.t})
CREATE (a)-[:CONNECTS_TO {port: e.port}]->(b);
