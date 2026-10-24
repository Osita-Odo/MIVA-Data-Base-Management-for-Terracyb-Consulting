// =====================================================================
// Portfolio 4 / Neo4j step 1: attack-surface graph for one client
// Client 1 (Rhine Relief Network). Hostnames, IPs, asset types and
// criticality match the PostgreSQL seed data. CONNECTS_TO edges model
// network reachability observed during the engagement.
// Run: docker exec -i tc-neo4j cypher-shell -u neo4j -p terracyber-demo < graph/01_create_graph.cypher
// =====================================================================

MATCH (n) DETACH DELETE n;

CREATE CONSTRAINT asset_host IF NOT EXISTS FOR (a:Asset) REQUIRE a.hostname IS UNIQUE;
CREATE CONSTRAINT vuln_cve   IF NOT EXISTS FOR (v:Vulnerability) REQUIRE v.cve IS UNIQUE;

// ---------- Client and sites ----------
CREATE (c:Client {client_id: 1, name: 'Rhine Relief Network', sector: 'ngo'})
CREATE (ho:Site {site_id: 1,  name: 'Head office'})
CREATE (dc:Site {site_id: 21, name: 'Data centre'})
CREATE (c)-[:HAS_SITE]->(ho)
CREATE (c)-[:HAS_SITE]->(dc);

// ---------- Assets ----------
UNWIND [
  {h: 'rhiner-1-001',  ip: '10.1.0.2',   type: 'workstation', crit: 'critical', inet: true,  site: 1},
  {h: 'rhiner-1-002',  ip: '10.1.0.3',   type: 'network',     crit: 'medium',   inet: false, site: 1},
  {h: 'rhiner-1-003',  ip: '10.1.0.4',   type: 'network',     crit: 'low',      inet: true,  site: 1},
  {h: 'rhiner-1-007',  ip: '10.1.0.8',   type: 'workstation', crit: 'critical', inet: true,  site: 1},
  {h: 'rhiner-1-008',  ip: '10.1.0.9',   type: 'server',      crit: 'low',      inet: false, site: 1},
  {h: 'rhiner-1-009',  ip: '10.1.0.10',  type: 'server',      crit: 'medium',   inet: false, site: 1},
  {h: 'rhiner-1-010',  ip: '10.1.0.11',  type: 'application', crit: 'critical', inet: true,  site: 1},
  {h: 'rhiner-21-002', ip: '10.21.0.3',  type: 'application', crit: 'critical', inet: false, site: 21},
  {h: 'rhiner-21-003', ip: '10.21.0.4',  type: 'cloud',       crit: 'critical', inet: false, site: 21},
  {h: 'rhiner-21-004', ip: '10.21.0.5',  type: 'cloud',       crit: 'critical', inet: false, site: 21},
  {h: 'rhiner-21-008', ip: '10.21.0.9',  type: 'workstation', crit: 'medium',   inet: true,  site: 21},
  {h: 'rhiner-21-014', ip: '10.21.0.15', type: 'network',     crit: 'low',      inet: false, site: 21},
  {h: 'rhiner-21-017', ip: '10.21.0.18', type: 'server',      crit: 'medium',   inet: false, site: 21}
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
  {h: 'rhiner-1-010',  cve: 'CVE-2021-44228'},
  {h: 'rhiner-1-003',  cve: 'CVE-2024-3400'},
  {h: 'rhiner-1-007',  cve: 'CVE-2019-0708'},
  {h: 'rhiner-21-008', cve: 'CVE-2021-34527'}
] AS row
MATCH (a:Asset {hostname: row.h}), (v:Vulnerability {cve: row.cve})
CREATE (a)-[:AFFECTED_BY {status: 'open', engagement_id: 21}]->(v);

// ---------- Network reachability ----------
UNWIND [
  {f: 'rhiner-1-003',  t: 'rhiner-1-002',  port: 'any'},
  {f: 'rhiner-1-002',  t: 'rhiner-1-001',  port: 'any'},
  {f: 'rhiner-1-002',  t: 'rhiner-1-008',  port: '445'},
  {f: 'rhiner-1-002',  t: 'rhiner-1-009',  port: '5432'},
  {f: 'rhiner-1-007',  t: 'rhiner-1-002',  port: 'any'},
  {f: 'rhiner-1-010',  t: 'rhiner-1-009',  port: '5432'},
  {f: 'rhiner-1-009',  t: 'rhiner-21-014', port: 'any'},
  {f: 'rhiner-21-008', t: 'rhiner-21-014', port: 'any'},
  {f: 'rhiner-21-014', t: 'rhiner-21-002', port: '443'},
  {f: 'rhiner-21-014', t: 'rhiner-21-017', port: '22'},
  {f: 'rhiner-21-017', t: 'rhiner-21-003', port: '443'},
  {f: 'rhiner-21-017', t: 'rhiner-21-004', port: '443'}
] AS e
MATCH (a:Asset {hostname: e.f}), (b:Asset {hostname: e.t})
CREATE (a)-[:CONNECTS_TO {port: e.port}]->(b);
