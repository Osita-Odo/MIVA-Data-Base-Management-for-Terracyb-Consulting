-- Two-terminal lock demo, session B (manager B). Start about 1 second after
-- session_a.sql: B waits on A's row lock, then reads A's committed value.
\echo `date +%T` session B starts
BEGIN;
\echo `date +%T` B requests the same row ...
SELECT hours_allocated FROM ead.engagement_staff WHERE engagement_id = 1 AND consultant_id = 6 FOR UPDATE;
\echo `date +%T` B got the row lock
UPDATE ead.engagement_staff SET hours_allocated = hours_allocated + 5 WHERE engagement_id = 1 AND consultant_id = 6;
COMMIT;
SELECT hours_allocated AS final FROM ead.engagement_staff WHERE engagement_id = 1 AND consultant_id = 6;
-- Reset for the next run: UPDATE ead.engagement_staff SET hours_allocated = 50 WHERE engagement_id = 1 AND consultant_id = 6;
