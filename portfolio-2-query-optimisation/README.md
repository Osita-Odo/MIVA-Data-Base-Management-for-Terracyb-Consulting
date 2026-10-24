# Portfolio 2: Query Processing and Optimisation

**Case study:** TerraCyber Consulting EAD
**DBMS:** PostgreSQL 16
**Marks:** 7

## 1. What this portfolio delivers

| Evidence required by the brief | Where it is |
| --- | --- |
| SQL queries | [`queries/`](queries) (9 business queries, one file each) |
| Query results | `results/query-results/*.txt`, produced by `run_queries.sh` |
| Execution plans | `plans/before/` and `plans/after/`, produced by `run_benchmark.sh` |
| Indexing and optimisation evidence | [`indexes.sql`](indexes.sql), `results/timings.md`, [`join_strategies.sql`](join_strategies.sql) |
| Performance analysis | Section 4 below |

## Key decisions and reasons

Full register with alternatives: [docs/design-decisions.md](../docs/design-decisions.md).

| Decision | Reason | ID |
| --- | --- | --- |
| Each query answers a TerraCyber business question and shows a different SQL feature | Shows the database serving its purpose and covers joins, CTEs, window functions, ROLLUP and full-text search without repetition | D34 |
| One optimisation per plan problem (partial, covering, GIN, materialised view) | Each technique is matched to the specific reason the baseline plan was slow | D35 to D40 |
| No new index for Q3, Q5, Q6a and Q8 | Demonstrates when an index does not help or when an existing one is enough; every extra index slows writes | D37, D41 |
| Median of 5 warm runs, scripted drop and recreate | Resists outliers, is reproducible, and guarantees a fair before/after comparison | D42 |
| Join methods compared by planner settings | Isolates the effect of the join algorithm alone | D43 |

## 2. The queries

Each query answers a question TerraCyber managers actually ask.

| # | Business question | SQL features shown |
| --- | --- | --- |
| Q1 | Which open critical findings have waited longest? (triage queue) | View over a 4-table join, filter, ORDER BY + LIMIT |
| Q2 | How many days do we take to fix findings, per service line and quarter? | GROUP BY on an expression, AVG on date arithmetic |
| Q3 | Which clients are below 70% ISO/IEC 27001 compliance? | CTE, `FILTER` conditional aggregates, HAVING |
| Q4 | What are the 5 riskiest assets at each client site? | Window function `RANK() OVER (PARTITION BY ...)` |
| Q5 | How does planned staff cost compare with each engagement's budget? | LEFT JOINs, derived table, COALESCE, NULLIF |
| Q6a | How many findings mention "password"? (ILIKE) | Pattern matching with a leading wildcard |
| Q6b | Same question with full-text search | `to_tsvector` / `to_tsquery` |
| Q7 | Where is Log4Shell (CVE-2021-44228) still unfixed? | Selective equality lookup |
| Q8 | How much open risk does each office (Lagos, Abuja, Port Harcourt) carry, by geopolitical zone? | 6-table join through the `state` lookup, `GROUP BY ROLLUP` subtotals |

## 3. How to run

Load Portfolio 1 first (`schema.sql`, then `seed.sql`). Then:

```bash
./run_queries.sh          # saves each result set to results/query-results/
./run_benchmark.sh        # drops optimisations, times every query, creates them, times again
psql -d ead -f join_strategies.sql > plans/join-strategies.txt
```

`run_benchmark.sh` takes the median of 5 runs of `EXPLAIN (ANALYZE, BUFFERS)` with a warm cache. It writes the full plans and a summary table to `results/timings.md`. Both scripts read the usual `PGHOST`, `PGUSER` and `PGPASSWORD` environment variables.

## 4. Optimisations and analysis

The `finding` table holds about 66,000 rows. Without Portfolio 2 indexes, every query on it starts with a sequential scan. Each optimisation targets one specific plan problem.

| Query | Problem in the baseline plan | Optimisation | Expected result |
| --- | --- | --- | --- |
| Q1 | Scans all findings, then sorts about 3,500 rows to return 50 | **Partial index** on `found_on`, limited to open or in-progress critical findings | Index Scan returns rows already in order and stops after 50. Largest gain among the B-tree cases. |
| Q2 | Aggregates about 50,000 fixed findings on every run | **Materialised view** `mv_mttr` plus a unique index | Reading a few dozen precomputed rows. Trade-off: data is only as fresh as the last `REFRESH MATERIALIZED VIEW`. |
| Q3 | About 2,200 rows in `control_assessment` | **None added** | No real change. With a small table that the query reads mostly in full, a sequential scan is already the cheapest plan. |
| Q4 | Reads every finding to sum unresolved CVSS | **Covering partial index** `(asset_id) INCLUDE (cvss_score)` on unresolved rows | Index Only Scan reads a smaller structure and never visits the table. Moderate gain, because the aggregation still has to run. |
| Q5 | Small tables, hash joins | **None.** Join algorithms compared in `join_strategies.sql` | Planner picks hash joins. Forcing merge join or nested loops gives slower or equal plans at this size. |
| Q6a | `ILIKE '%password%'` cannot use a B-tree | **None for ILIKE** | Stays a sequential scan. A B-tree only helps for left-anchored patterns such as `'password%'`. |
| Q6b | `to_tsvector` is computed for every row on every run | **GIN expression index** on `to_tsvector('english', title)` | Bitmap Index Scan on the GIN index. The biggest single improvement after Q2. |
| Q7 | Equality filter on a rare value, but a full scan | **Partial B-tree** on `cve_id` where it is not null | Bitmap Index Scan. Index stays small because most findings have no CVE. |
| Q8 | Scans all findings to keep the unresolved ones, then joins through `state` to the office | **Reuses** the Q4 covering partial index | Shows that one well-chosen index can serve several queries. Compare the before and after plans to see whether the planner chose it. |

**Points to write about in your own words after running the benchmark:**

1. Compare the planner's estimated `rows=` with the `actual ... rows=` in each plan. Note where they differ and why (for example the correlation between `status` and `severity` in query 4 of `join_strategies.sql`).
2. Explain why Q3, Q5 and Q6a did not improve. Knowing when an index does not help is part of the marks for performance analysis.
3. Consider the cost side: every index slows `INSERT` and `UPDATE` on `finding` and uses disk. Check sizes with:

```sql
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes WHERE relname = 'finding';
```

4. Optional extension: `CREATE EXTENSION pg_trgm;` and a GIN trigram index make Q6a's `ILIKE '%password%'` indexable. Rerun and compare.

## 5. Results

After running the scripts, paste `results/timings.md` here, then add 3 to 5 sentences of interpretation.

| Query | Before (ms) | After (ms) | Speed-up | Access path after |
| --- | ---: | ---: | ---: | --- |
| Q1 | | | | |
| Q2 | | | | |
| Q3 | | | | |
| Q4 | | | | |
| Q5 | | | | |
| Q6a | | | | |
| Q6b | | | | |
| Q7 | | | | |
| Q8 | | | | |

Hardware used: _(laptop model, CPU, RAM)_. Timings vary between machines; the ratios matter more than the absolute times.

## 6. Evidence checklist

- [ ] `results/query-results/` committed
- [ ] `plans/before/` and `plans/after/` committed
- [ ] `results/timings.md` committed and copied into section 5
- [ ] Screenshot of one before/after plan pair (Q1 is the clearest)
- [ ] `plans/join-strategies.txt` committed
