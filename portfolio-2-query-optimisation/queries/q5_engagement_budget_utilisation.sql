-- =====================================================================
-- Q5  Planned staff cost and invoicing against budget per engagement
-- Business question: which engagements are at risk of going over budget?
-- Features: LEFT JOINs, derived table, COALESCE, NULLIF
-- Used in join_strategies.sql to compare hash, merge and nested-loop joins
-- =====================================================================
SELECT e.engagement_id,
       c.name                                                    AS client_name,
       sl.name                                                   AS service_line,
       e.budget_ngn,
       -- planned cost = allocated hours x each consultant's hourly rate;
       -- COALESCE turns "no staff yet" (NULL) into 0
       COALESCE(sum(es.hours_allocated * co.hourly_rate_ngn), 0) AS planned_cost_ngn,
       -- NULLIF prevents a division by zero for a zero budget
       round(100 * COALESCE(sum(es.hours_allocated * co.hourly_rate_ngn), 0)
             / NULLIF(e.budget_ngn, 0), 1)                      AS pct_of_budget,
       COALESCE(inv.invoiced_ngn, 0)                             AS invoiced_ngn
FROM engagement e
JOIN client c        ON c.client_id      = e.client_id
JOIN service_line sl ON sl.service_id    = e.service_id
-- LEFT JOIN keeps engagements that have no staff or no invoices yet
LEFT JOIN engagement_staff es ON es.engagement_id = e.engagement_id
LEFT JOIN consultant co       ON co.consultant_id = es.consultant_id
-- Invoices are totalled in a derived table first. Joining invoice rows
-- directly would multiply them by the number of staff rows (fan-out)
-- and inflate both sums.
LEFT JOIN (SELECT engagement_id, sum(amount_ngn) AS invoiced_ngn
           FROM invoice GROUP BY engagement_id) inv
       ON inv.engagement_id = e.engagement_id
GROUP BY e.engagement_id, c.name, sl.name, e.budget_ngn, inv.invoiced_ngn
ORDER BY pct_of_budget DESC NULLS LAST;     -- most at-risk first; engagements without a
                                            -- budget percentage go to the end
