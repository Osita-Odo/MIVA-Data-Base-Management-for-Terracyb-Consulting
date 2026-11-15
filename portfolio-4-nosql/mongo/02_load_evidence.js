// =====================================================================
// Portfolio 4 / MongoDB step 2: load evidence documents
// 6 hand-written documents (one of each shape) plus 3,000 generated
// vulnerability scans so that index effects are measurable (D53).
// Scan results are EMBEDDED in their scan, because they are always read
// together; engagements and clients are REFERENCED by id, because they
// change and live in PostgreSQL (D51).
// engagement_id and client_id match the PostgreSQL seed data.
// Run: docker exec -it tc-mongo mongosh terracyb /scripts/02_load_evidence.js
// =====================================================================
db = db.getSiblingDB("terracyb");
db.evidence.deleteMany({});

// ---------- 1. Hand-written examples: same collection, different shapes ----------
db.evidence.insertMany([
  {
    _id: "EV-2026-00001", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.8.8",
    type: "vuln_scan", collected_by: "consultant18", collected_at: new Date("2026-03-02T09:14:00Z"),
    scanner: { name: "OpenVAS", version: "23.1", profile: "Full and fast" },
    target_range: "10.1.0.0/24",
    results: [
      { host: "lagoon-1-010", ip: "10.1.0.11", port: 443, protocol: "tcp", cve: "CVE-2021-44228",
        title: "Apache Log4j remote code execution (Log4Shell)", cvss: 10.0, status: "open" },
      { host: "lagoon-1-007", ip: "10.1.0.8", port: 3389, protocol: "tcp", cve: "CVE-2019-0708",
        title: "Windows RDP remote code execution (BlueKeep)", cvss: 9.8, status: "open" },
      { host: "lagoon-1-003", ip: "10.1.0.4", port: 443, protocol: "tcp",
        title: "Outdated TLS configuration allows TLS 1.0", cvss: 5.3, status: "open" }
    ],
    tags: ["perimeter", "external-scan"]
  },
  {
    _id: "EV-2026-00002", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.5.1",
    type: "policy_document", collected_by: "consultant6", collected_at: new Date("2026-03-03T11:00:00Z"),
    document: { title: "Information Security Policy", version: "3.2", owner: "Head of IT",
                approved_on: new Date("2025-11-20"), pages: 14, file_ref: "policies/isp-v3.2.pdf",
                sha256: "9f2c1e7b0a4d5c6e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e" },
    review: { outcome: "partial", comment: "Policy exists but no annual review evidence." },
    tags: ["policy", "governance"]
  },
  {
    _id: "EV-2026-00003", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.8.20",
    type: "config_snapshot", collected_by: "consultant19", collected_at: new Date("2026-03-04T08:30:00Z"),
    device: { hostname: "lagoon-1-002", vendor: "FortiGate", model: "60F", firmware: "7.2.8" },
    firewall_rules: [
      { id: 1, src: "any", dst: "10.1.0.11", service: "HTTPS", action: "accept", logging: true },
      { id: 7, src: "any", dst: "10.1.0.8", service: "RDP", action: "accept", logging: false },
      { id: 99, src: "any", dst: "any", service: "ALL", action: "deny", logging: true }
    ],
    issues: ["Rule 7 exposes RDP to the internet", "Rule 7 has logging disabled"],
    tags: ["network", "firewall"]
  },
  {
    _id: "EV-2026-00004", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.6.3",
    type: "interview_note", collected_by: "consultant6", collected_at: new Date("2026-03-05T14:00:00Z"),
    interviewee_role: "Programme manager",
    questions: [
      { q: "When did staff last complete security awareness training?", a: "About 18 months ago." },
      { q: "Is training part of onboarding?", a: "Not formally." }
    ],
    conclusion: "non_compliant",
    tags: ["people", "training"]
  },
  {
    _id: "EV-2026-00005", engagement_id: 1, client_id: 1, control_ref: "ISO27001:A.5.17",
    type: "screenshot", collected_by: "consultant18", collected_at: new Date("2026-03-05T15:20:00Z"),
    image: { file_ref: "screens/m365-mfa-settings.png", width: 1920, height: 1080 },
    caption: "Microsoft 365 admin centre: MFA enforced for 62 of 75 accounts",
    tags: ["identity", "mfa"]
  },
  {
    _id: "EV-2026-00006", engagement_id: 1, client_id: 1, control_ref: "NDPA:S.28",
    type: "policy_document", collected_by: "consultant6", collected_at: new Date("2026-03-06T10:00:00Z"),
    document: { title: "Data Privacy Impact Assessment: beneficiary registration app", version: "1.0",
                owner: "Data Protection Officer", high_risk_processing: true,
                file_ref: "ndpa/dpia-beneficiary-app-2026.pdf" },
    review: { outcome: "partial", comment: "DPIA completed, but no record of consulting the NDPC on the high residual risk." },
    tags: ["ndpa", "privacy"]
  }]);
print("Inserted 6 hand-written evidence documents.");

// ---------- 2. Generated scans (deterministic pseudo-random numbers) ----------
// mulberry32: small seeded generator, so every run loads identical data
let seed = 42;
function rnd() {
  seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
function pick(arr) { return arr[Math.floor(rnd() * arr.length)]; }

const templates = [
  { title: "Outdated TLS configuration allows TLS 1.0", cvss: 5.3, port: 443 },
  { title: "Default credentials on administrative interface", cvss: 9.1, port: 8443 },
  { title: "Missing operating system security patches", cvss: 7.5, port: 445 },
  { title: "SMB signing not required", cvss: 5.9, port: 445 },
  { title: "Remote Desktop exposed to the internet", cvss: 8.1, port: 3389 },
  { title: "Missing HTTP security headers", cvss: 3.7, port: 80 },
  { title: "SQL injection in login form", cvss: 9.8, port: 443 },
  { title: "Self-signed certificate on internal portal", cvss: 2.6, port: 443 },
  { title: "Apache Log4j remote code execution (Log4Shell)", cvss: 10.0, port: 8080, cve: "CVE-2021-44228" },
  { title: "PAN-OS GlobalProtect command injection", cvss: 10.0, port: 443, cve: "CVE-2024-3400" },
  { title: "Citrix NetScaler session token leak (Citrix Bleed)", cvss: 9.4, port: 443, cve: "CVE-2023-4966" },
  { title: "Windows Print Spooler remote code execution", cvss: 8.8, port: 445, cve: "CVE-2021-34527" }
];
const controls = ["ISO27001:A.8.8", "ISO27001:A.8.20", "ISO27001:A.8.9", "ISO27001:A.8.21", "ISO27001:A.8.16"];
const scanners = [{ name: "OpenVAS", version: "23.1" }, { name: "Nessus", version: "10.7" }, { name: "Nmap NSE", version: "7.95" }];

// Hostnames and IPs come from the PostgreSQL asset table (see export_assets.sh)
const fs = require("fs");
const assetFile = ["/scripts/assets.json", "./assets.json", "./mongo/assets.json"].find(p => fs.existsSync(p));
if (!assetFile) { throw new Error("assets.json not found. Run export_assets.sh first."); }
const assetsByClient = {};
JSON.parse(fs.readFileSync(assetFile, "utf8")).forEach(a => {
  (assetsByClient[a.client_id] = assetsByClient[a.client_id] || []).push(a);
});

const docs = [];
for (let i = 7; i <= 3006; i++) {
  // Compliance (ids 1-20) and advisory (ids 21-40) engagements; client = ((id - 1) % 20) + 1
  const engagement = 1 + Math.floor(rnd() * 40);
  const client = ((engagement - 1) % 20) + 1;
  const results = [];
  const n = 5 + Math.floor(rnd() * 36);
  for (let r = 0; r < n; r++) {
    const t = pick(templates);
    const asset = pick(assetsByClient[client]);
    const res = {
      host: asset.hostname,
      ip: asset.ip,
      port: t.port, protocol: "tcp", title: t.title,
      cvss: t.cve ? t.cvss : Math.round(Math.min(10, Math.max(0.1, t.cvss + (rnd() - 0.5) * 2)) * 10) / 10,
      status: pick(["open", "open", "fixed", "accepted"])
    };
    if (t.cve) res.cve = t.cve;
    results.push(res);
  }
  docs.push({
    _id: "EV-2026-" + String(i).padStart(5, "0"),
    engagement_id: engagement,
    client_id: client,
    control_ref: pick(controls),
    type: "vuln_scan",
    collected_by: "consultant" + (14 + Math.floor(rnd() * 11)),
    collected_at: new Date(Date.UTC(2023 + Math.floor(rnd() * 4), Math.floor(rnd() * 12), 1 + Math.floor(rnd() * 28))),
    scanner: pick(scanners),
    results: results,
    tags: [pick(["internal-scan", "external-scan"]), pick(["quarterly", "ad-hoc"])]
  });
}
db.evidence.insertMany(docs);
print("Inserted " + docs.length + " generated scan documents.");
print("Total documents: " + db.evidence.countDocuments());
