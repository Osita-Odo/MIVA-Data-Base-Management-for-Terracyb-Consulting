#!/bin/bash
# pg-portharcourt start-up: on first start, clone the Lagos primary with pg_basebackup.
#   -R  writes standby.signal and primary_conninfo, so the server starts as a standby
#   -S  uses the replication slot, so the primary keeps WAL the replica still needs
#   -c fast  asks the primary for an immediate checkpoint instead of waiting
set -e
DATA=/var/lib/postgresql/data
PRIMARY_HOST="${PRIMARY_HOST:-pg-lagos}"

# PG_VERSION exists only in an initialised data directory, so the backup
# runs once; later restarts go straight to starting the standby.
if [ ! -s "$DATA/PG_VERSION" ]; then
    echo "Waiting for $PRIMARY_HOST to accept TCP connections ..."
    until pg_isready -h "$PRIMARY_HOST" -p 5432 -U replicator -q; do sleep 2; done
    echo "Taking base backup from $PRIMARY_HOST ..."
    pg_basebackup -h "$PRIMARY_HOST" -p 5432 -U replicator -D "$DATA" -X stream -S replica1 -R -P -c fast
    chmod 700 "$DATA"                      # PostgreSQL refuses a data directory others can read
fi

# exec replaces the shell, so the container stops cleanly with the server
exec postgres -D "$DATA" -c hot_standby=on
