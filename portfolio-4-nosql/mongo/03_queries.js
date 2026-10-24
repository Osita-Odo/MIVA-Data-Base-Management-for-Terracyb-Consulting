// =====================================================================
// Portfolio 4 / MongoDB step 3: queries, aggregation, update, indexes
// Run: docker exec -it tc-mongo mongosh terracyber /scripts/03_queries.js
// Save output: ... /scripts/03_queries.js > ../evidence-samples/mongo-output.txt
// =====================================================================
db = db.getSiblingDB("terracyber");

function title(t) { print("\n=== " + t + " ==="); }
function show(cursorOrArray) { (Array.isArray(cursorOrArray) ? cursorOrArray : cursorOrArray.toArray()).forEach(d => printjson(d)); }
function planSummary(explained) {
  const stages = JSON.stringify(explained.queryPlanner.winningPlan).match(/"stage":"[A-Z_]+"/g) || [];
  const s = explained.executionStats;
  return {
    stages: stages.map(x => x.split(":")[1].replace(/"/g, "")).join(" <- "),
    docsExamined: s.totalDocsExamined,
    keysExamined: s.totalKeysExamined,
    returned: s.nReturned,
    timeMs: s.executionTimeMillis
  };
}

// ---------- Q1: one engagement's evidence for one control (simple find) ----------
title("Q1  Evidence for engagement 1, control ISO27001:A.8.8 (projection)");
show(db.evidence.find(
  { engagement_id: 1, control_ref: "ISO27001:A.8.8" },
  { _id: 1, type: 1, collected_at: 1, "scanner.name": 1 }
).sort({ collected_at: -1 }).limit(5));

// ---------- Q2: query inside nested arrays ----------
title("Q2  Scans with an OPEN result on port 3389 scoring 8 or more ($elemMatch)");
print("Matching documents: " + db.evidence.countDocuments({
  type: "vuln_scan",
  results: { $elemMatch: { port: 3389, cvss: { $gte: 8 }, status: "open" } }
}));

// ---------- Q3: aggregation pipeline ----------
title("Q3  Top 10 hosts by number of open high or critical results (aggregation)");
show(db.evidence.aggregate([
  { $match: { type: "vuln_scan" } },
  { $unwind: "$results" },
  { $match: { "results.cvss": { $gte: 7 }, "results.status": "open" } },
  { $group: { _id: { client: "$client_id", host: "$results.host" },
              open_high_or_critical: { $sum: 1 },
              max_cvss: { $max: "$results.cvss" },
              cves: { $addToSet: "$results.cve" } } },
  { $sort: { open_high_or_critical: -1, max_cvss: -1 } },
  { $limit: 10 }
]));

title("Q4  Evidence coverage per control for engagement 1 (group by control and type)");
show(db.evidence.aggregate([
  { $match: { engagement_id: 1 } },
  { $group: { _id: "$control_ref", items: { $sum: 1 }, types: { $addToSet: "$type" } } },
  { $sort: { _id: 1 } }
]));

// ---------- Q5: update inside an array with arrayFilters ----------
title("Q5  Mark every Log4Shell result in engagement 1 as fixed (arrayFilters)");
const upd = db.evidence.updateMany(
  { engagement_id: 1, "results.cve": "CVE-2021-44228" },
  { $set: { "results.$[r].status": "fixed", "results.$[r].fixed_on": new Date("2026-03-20") },
    $addToSet: { tags: "log4shell-remediated" } },
  { arrayFilters: [{ "r.cve": "CVE-2021-44228" }] }
);
printjson({ matched: upd.matchedCount, modified: upd.modifiedCount });

// ---------- Indexes: measure before and after ----------
title("Indexes: explain('executionStats') BEFORE");
db.evidence.dropIndexes();      // keeps only _id
const qA = { engagement_id: 10, control_ref: "ISO27001:A.8.8" };
const qB = { "results.cve": "CVE-2024-3400" };
printjson({ query: "engagement + control", ...planSummary(db.evidence.find(qA).explain("executionStats")) });
printjson({ query: "results.cve (nested)", ...planSummary(db.evidence.find(qB).explain("executionStats")) });

db.evidence.createIndex({ engagement_id: 1, control_ref: 1 }, { name: "idx_engagement_control" });
db.evidence.createIndex({ "results.cve": 1 }, { name: "idx_results_cve", sparse: true });   // multikey
db.evidence.createIndex({ "results.title": "text", "document.title": "text" }, { name: "idx_text" });

title("Indexes: explain('executionStats') AFTER");
printjson({ query: "engagement + control", ...planSummary(db.evidence.find(qA).explain("executionStats")) });
printjson({ query: "results.cve (nested)", ...planSummary(db.evidence.find(qB).explain("executionStats")) });

title("Text search with the text index: 'security policy'");
show(db.evidence.find({ $text: { $search: "\"security policy\"" } }, { _id: 1, type: 1, "document.title": 1 }).limit(5));

title("Index list");
db.evidence.getIndexes().forEach(ix => print(ix.name + "  " + JSON.stringify(ix.key)));
