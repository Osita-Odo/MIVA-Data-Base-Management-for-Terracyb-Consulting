#!/bin/bash
# Runs once, when pg-lagos (the primary) initialises its data directory.
# Creates the replication user and a physical replication slot, and
# allows replication connections from the Docker network.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator-demo';
    SELECT pg_create_physical_replication_slot('replica1');
EOSQL
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
