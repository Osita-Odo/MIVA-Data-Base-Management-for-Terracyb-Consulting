-- =====================================================================
-- Q6b  The same keyword search with PostgreSQL full-text search
-- to_tsvector splits the title into normalised words (lexemes), for
-- example "passwords" -> "password". to_tsquery builds the search term
-- and @@ tests for a match.
-- Optimised by: idx_finding_title_fts, a GIN index on the SAME expression
-- to_tsvector('english', title). The expression must match exactly, or
-- the planner cannot use the index.
-- =====================================================================
SELECT count(*) AS matches
FROM finding
WHERE to_tsvector('english', title) @@ to_tsquery('english', 'password');
