#!/bin/bash
# One-shot: waits for mongo1-3, then initiates replica set rs0.
# Priorities make mongo1 the preferred primary at start-up.
set -e
# Containers start in any order: wait until all three answer a ping
for h in mongo1 mongo2 mongo3; do
  until mongosh --host "$h" --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
    echo "waiting for $h ..."; sleep 2
  done
done

# rs.status() throws if the set is not initiated yet. Initiating only in
# that case makes the script safe to run more than once.
mongosh --host mongo1 --quiet --eval '
try {
  rs.status();
  print("Replica set already initiated");
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [
      { _id: 0, host: "mongo1:27017", priority: 2 },
      { _id: 1, host: "mongo2:27017", priority: 1 },
      { _id: 2, host: "mongo3:27017", priority: 1 }
    ]
  });
  print("Replica set rs0 initiated");
}'
