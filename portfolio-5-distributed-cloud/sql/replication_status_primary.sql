-- Run on pg-lagos (primary): who is replicating from me, and how far behind are they?
--   docker exec -i pg-lagos psql -U postgres -d ead -f /sql/replication_status_primary.sql
\x on   -- expanded display: one column per line, easier to read for wide rows

-- One row per connected standby.
--   state      'streaming' means the replica is receiving WAL live
--   sync_state 'async' (default) or 'sync' (see README section 5.5)
--   *_lsn      positions in the WAL stream: sent > written > flushed > replayed
--   *_lag      time between a commit on the primary and each step on the replica
SELECT application_name, client_addr, state, sync_state,
       sent_lsn, write_lsn, flush_lsn, replay_lsn,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_gap_bytes,
       write_lag, flush_lag, replay_lag
FROM pg_stat_replication;

-- The replication slot makes the primary keep WAL until the replica has it,
-- so a replica that disconnects for a while can still catch up.
SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots;
\x off
-- false = this server is a primary; current_lsn is where its WAL has reached
SELECT pg_is_in_recovery() AS is_standby, pg_current_wal_lsn() AS current_lsn;
