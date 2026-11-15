// =====================================================================
// Portfolio 4 / MongoDB step 1: create the evidence collection
// Document model: one document per piece of audit evidence.
// Different evidence types have different shapes, so the validator only
// enforces the fields every type shares. Type-specific fields stay flexible.
// Run: docker exec -it tc-mongo mongosh terracyb /scripts/01_create_collection.js
// =====================================================================
db = db.getSiblingDB("terracyb");
db.evidence.drop();

db.createCollection("evidence", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "engagement_id", "client_id", "control_ref", "type", "collected_by", "collected_at"],
      properties: {
        _id:           { bsonType: "string", pattern: "^EV-[0-9]{4}-[0-9]{5}$" },
        engagement_id: { bsonType: "int", minimum: 1, description: "engagement.engagement_id in PostgreSQL" },
        client_id:     { bsonType: "int", minimum: 1 },
        control_ref:   { bsonType: "string", description: "e.g. ISO27001:A.8.8" },
        type: {
          enum: ["vuln_scan", "policy_document", "config_snapshot", "interview_note", "screenshot"]
        },
        collected_by:  { bsonType: "string" },
        collected_at:  { bsonType: "date" },
        tags:          { bsonType: "array", items: { bsonType: "string" } },
        results: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["host", "cvss"],
            properties: {
              host: { bsonType: "string" },
              cvss: { bsonType: ["double", "int"], minimum: 0, maximum: 10 }
            }
          }
        }
      }
    }
  },
  validationAction: "error"
});

print("Collection 'evidence' created with a $jsonSchema validator.");

// Show that the validator rejects a document with an unknown type
try {
  db.evidence.insertOne({
    _id: "EV-2026-99999", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.8.8",
    type: "random_file", collected_by: "test", collected_at: new Date()
  });
} catch (e) {
  print("Validator test, expected failure: " + e.errmsg);
}
