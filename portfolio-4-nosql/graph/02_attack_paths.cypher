// =====================================================================
// Portfolio 4 / Neo4j step 2: attack-path queries
// Run: docker exec -i tc-neo4j cypher-shell -u neo4j -p terracyb-demo < graph/02_attack_paths.cypher
// =====================================================================

// G1. Attack paths: from an internet-facing asset with a vulnerability of
//     CVSS 9 or more, through the network, to any critical asset (1 to 4 hops).
MATCH (entry:Asset {internet_facing: true})-[:AFFECTED_BY]->(v:Vulnerability)
WHERE v.cvss >= 9
MATCH p = (entry)-[:CONNECTS_TO*1..4]->(target:Asset {criticality: 'critical'})
RETURN entry.hostname AS entry_point, v.name AS exploited_with,
       [n IN nodes(p) | n.hostname] AS path, length(p) AS hops, target.hostname AS target
ORDER BY hops, entry_point;

// G2. Shortest route from each exploitable entry point to the cloud asset lagoon-2-009.
MATCH (entry:Asset {internet_facing: true})-[:AFFECTED_BY]->(v:Vulnerability)
WHERE v.cvss >= 9
MATCH p = shortestPath((entry)-[:CONNECTS_TO*..6]->(:Asset {hostname: 'lagoon-2-009'}))
RETURN entry.hostname AS entry_point, [n IN nodes(p) | n.hostname] AS shortest_path, length(p) AS hops
ORDER BY hops;

// G3. Blast radius: how many assets each exploitable entry point can reach within 3 hops.
MATCH (entry:Asset)-[:AFFECTED_BY]->(v:Vulnerability)
WHERE entry.internet_facing AND v.cvss >= 9
OPTIONAL MATCH (entry)-[:CONNECTS_TO*1..3]->(reach:Asset)
RETURN entry.hostname AS entry_point, v.cve AS cve, count(DISTINCT reach) AS reachable_assets
ORDER BY reachable_assets DESC;

// G4. Choke points: the internal assets that sit on the most attack paths.
//     Segmenting these gives the biggest risk reduction.
MATCH (entry:Asset {internet_facing: true})-[:AFFECTED_BY]->(v:Vulnerability)
WHERE v.cvss >= 9
MATCH p = (entry)-[:CONNECTS_TO*1..4]->(:Asset {criticality: 'critical'})
UNWIND nodes(p)[1..-1] AS hop
RETURN hop.hostname AS choke_point, hop.asset_type AS type, count(*) AS paths_through
ORDER BY paths_through DESC
LIMIT 5;
