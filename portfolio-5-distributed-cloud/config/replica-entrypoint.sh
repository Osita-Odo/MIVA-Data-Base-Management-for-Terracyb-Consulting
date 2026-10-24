#!/bin/bash
# pg-replica start-up: on first start, clone pg-primary with pg_basebackup.
#   -R  writes standby.signal and primary_conninfo, so the server starts as a standby
#   -S  uses the replication slot, so the primary keeps WAL the replica still needs
#   -c fast  asks the primary for an immediate checkpoint instead of waiting
set -e
DATA=/var/lib/postgresql/data

if [ ! -s "$DATA/PG_VERSION" ]; then
    echo "Waiting for pg-primary to accept TCP connections ..."
    until pg_isready -h pg-primary -p 5432 -U replicator -q; do sleep 2; done
    echo "Taking base backup from pg-primary ..."
    pg_basebackup -h pg-primary -p 5432 -U replicator -D "$DATA" -X stream -S replica1 -R -P -c fast
    chmod 700 "$DATA"
fi

exec postgres -D "$DATA" -c hot_standby=on
