-- Run on pg-replica: am I a standby, and how stale is my data?
--   docker exec -i pg-replica psql -U postgres -d ead -f /sql/replication_status_replica.sql
-- is_standby true     -> the server is replaying WAL and is read only
-- received vs replayed -> WAL that has arrived but is not yet applied
-- time_since_last...   -> how stale the replica's data may be (NULL if no
--                         transaction has been replayed since start-up)
SELECT pg_is_in_recovery()                        AS is_standby,
       pg_last_wal_receive_lsn()                  AS received_lsn,
       pg_last_wal_replay_lsn()                   AS replayed_lsn,
       now() - pg_last_xact_replay_timestamp()    AS time_since_last_replayed_commit;

-- The WAL receiver process: which primary it streams from, through which slot
SELECT status, sender_host, slot_name, last_msg_receipt_time FROM pg_stat_wal_receiver;
