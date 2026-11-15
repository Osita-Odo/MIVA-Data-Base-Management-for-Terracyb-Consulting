// =====================================================================
// Portfolio 5: MongoDB replica set, consistency and availability
// Run (connects to the whole set, so the driver follows the primary):
//   docker exec -i mongo-portharcourt mongosh "mongodb://mongo-lagos,mongo-portharcourt,mongo-abuja/terracyb?replicaSet=rs0" /scripts/replica-set-demo.js
// =====================================================================
db = db.getSiblingDB("terracyb");

// Prints each member with its role (PRIMARY / SECONDARY) and health (1 = up)
function members() {
  rs.status().members.forEach(m => print("  " + m.name.padEnd(26) + m.stateStr.padEnd(11) + "health=" + m.health));
}

print("=== 1. Replica set members ===");
members();

print("\n=== 2. Write with writeConcern majority (acknowledged by 2 of 3 nodes) ===");
// The timestamp makes the _id unique, so the demo can be rerun
const t0 = Date.now();
db.evidence_rs.insertOne(
  { _id: "EV-RS-" + t0, engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.8.13",
    type: "screenshot", collected_by: "consultant18", collected_at: new Date(), caption: "Backup job log" },
  { writeConcern: { w: "majority", wtimeout: 5000 } }
);
print("  acknowledged after " + (Date.now() - t0) + " ms");

print("\n=== 3. Read the same document with different guarantees ===");
// readPref   = WHICH node answers (primary, secondary, nearest)
// readConcern = HOW durable the returned data must be
//   majority  : only data acknowledged by most nodes (cannot be rolled back)
//   local     : whatever that node has now
//   available : like local, the fastest option on sharded clusters
const q = { _id: "EV-RS-" + t0 };
printjson({
  primary_majority:   db.evidence_rs.find(q).readPref("primary").readConcern("majority").toArray().length,
  secondary_local:    db.evidence_rs.find(q).readPref("secondary").readConcern("local").toArray().length,
  nearest_available:  db.evidence_rs.find(q).readPref("nearest").readConcern("available").toArray().length
});
print("  1 = found. A secondary read may return 0 if replication has not caught up yet (eventual consistency).");

print("\n=== 4. Replication lag per secondary ===");
// optimeDate = time of the last operation each member has applied
const st = rs.status();
const primary = st.members.find(m => m.stateStr === "PRIMARY");
st.members.filter(m => m.stateStr === "SECONDARY").forEach(m =>
  print("  " + m.name + " is " + ((primary.optimeDate - m.optimeDate) / 1000) + " s behind the primary"));

print("\n=== 5. w: 3 needs every node; it times out if one is down ===");
// wtimeout stops the client waiting forever. Note: on timeout the write is
// NOT undone; it still exists on the nodes that received it.
try {
  db.evidence_rs.insertOne({ _id: "EV-RS-ALL-" + Date.now(), engagement_id: 1, client_id: 1,
                             control_ref: "ISO27001:A.8.13", type: "screenshot",
                             collected_by: "consultant18", collected_at: new Date() },
                           { writeConcern: { w: 3, wtimeout: 3000 } });
  print("  w:3 write acknowledged by all 3 nodes");
} catch (e) {
  print("  w:3 write NOT fully acknowledged: " + e.codeName + " (" + e.message.split("\n")[0] + ")");
}
