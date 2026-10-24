-- =====================================================================
-- Q6a  Keyword search with ILIKE
-- Business question: how many findings relate to passwords?
-- ILIKE is case-insensitive pattern matching. The leading wildcard
-- ('%password') means the match can start anywhere in the title, so a
-- B-tree index cannot be used and PostgreSQL must scan every row.
-- This is the "index does not help" baseline for Q6b.
-- =====================================================================
SELECT count(*) AS matches
FROM finding
WHERE title ILIKE '%password%';
