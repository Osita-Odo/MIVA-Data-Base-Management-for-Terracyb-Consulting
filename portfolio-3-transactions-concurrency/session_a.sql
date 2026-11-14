-- Two-terminal lock demo, session A (manager A). Run in terminal A first,
-- then start session_b.sql in terminal B within 4 seconds. See README section 5.
\echo `date +%T` session A starts
BEGIN;
SELECT hours_allocated FROM ead.engagement_staff WHERE engagement_id = 1 AND consultant_id = 6 FOR UPDATE;
SELECT pg_sleep(4) \g /dev/null
\echo `date +%T` A has held the lock for 4 s
UPDATE ead.engagement_staff SET hours_allocated = hours_allocated + 10 WHERE engagement_id = 1 AND consultant_id = 6;
COMMIT;
\echo `date +%T` session A committed
