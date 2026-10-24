#!/bin/bash
# One-shot: waits for the three site members, then initiates replica set rs0.
# Priority 2 makes mongo-lagos (headquarters) the preferred primary.
set -e
# Containers start in any order: wait until all three answer a ping
for h in mongo-lagos mongo-portharcourt mongo-abuja; do
  until mongosh --host "$h" --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
    echo "waiting for $h ..."; sleep 2
  done
done

# rs.status() throws if the set is not initiated yet. Initiating only in
# that case makes the script safe to run more than once.
mongosh --host mongo-lagos --quiet --eval '
try {
  rs.status();
  print("Replica set already initiated");
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [
      { _id: 0, host: "mongo-lagos:27017",        priority: 2 },
      { _id: 1, host: "mongo-portharcourt:27017", priority: 1 },
      { _id: 2, host: "mongo-abuja:27017",        priority: 1 }
    ]
  });
  print("Replica set rs0 initiated");
}'
