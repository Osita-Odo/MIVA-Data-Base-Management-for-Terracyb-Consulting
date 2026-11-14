-- Run in a third terminal while session B is waiting: B shows wait_event_type = Lock.
SELECT pid, state, wait_event_type, wait_event, left(query, 40) AS query
FROM pg_stat_activity WHERE datname = 'ead' AND pid <> pg_backend_pid() AND query NOT LIKE '%pg_stat_activity%';
