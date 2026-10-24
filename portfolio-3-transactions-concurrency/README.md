# Portfolio 3: Transactions and Concurrency

**Case study:** TerraCyber Consulting EAD
**DBMS:** PostgreSQL 16 (default isolation level: READ COMMITTED)
**Marks:** 7

## 1. What this portfolio delivers

| Evidence required by the brief | Scenario | File |
| --- | --- | --- |
| Commit | 1. Close a finding and audit it atomically | [`01_commit_close_finding.sql`](01_commit_close_finding.sql) |
| Rollback | 2. Reject an overpayment; SAVEPOINT variant | [`02_rollback_overpayment.sql`](02_rollback_overpayment.sql) |
| Concurrency issue and control mechanism | 3. Lost update, fixed with `SELECT ... FOR UPDATE` | [`03_lost_update.sh`](03_lost_update.sh) |
| Isolation | 4. Non-repeatable read and write skew across isolation levels | [`04_isolation_levels.sh`](04_isolation_levels.sh) |
| Concurrency control (extra) | 5. Deadlock detection | [`05_deadlock.sh`](05_deadlock.sh) |
| Output evidence | Logs of every run | `output/*.log` |

## 2. How to run

Load Portfolio 1 first. Then run everything at once:

```bash
./run_all.sh            # writes output/01 ... output/05 logs
```

Or run one scenario at a time:

```bash
psql -d ead -f 01_commit_close_finding.sql
psql -d ead -f 02_rollback_overpayment.sql
./03_lost_update.sh
./04_isolation_levels.sh
./05_deadlock.sh
```

Scenarios 3 to 5 start two `psql` sessions in parallel and use `pg_sleep` to force a precise interleaving, so the result is the same on every run. Each line is timestamped so the order of events is visible. The scripts restore the rows they change. Scenarios 1 and 2 change one finding and one invoice each time they run.

## 3. Scenarios and what they prove

### Scenario 1: COMMIT (atomicity and durability)

Closing a finding changes `finding.status` and `fixed_on`. Trigger `trg_audit_finding` writes an `audit_log` row in the same transaction. After `COMMIT` both changes are permanent. Before it, no other session can see either.

### Scenario 2: ROLLBACK and SAVEPOINT (atomicity and consistency)

Trigger `trg_payment_within_invoice` raises an error if total payments would exceed the invoice.

- **Part A:** the first payment is valid, the second is not. The error puts the whole transaction into an aborted state; even `SELECT 1` is refused. `ROLLBACK` removes the valid first payment too, because a transaction is all or nothing.
- **Part B:** a `SAVEPOINT` after the first payment lets `ROLLBACK TO SAVEPOINT` discard only the failed step. The commit keeps half the payment and the invoice moves to `part_paid`.

The trigger also locks the invoice row (`FOR UPDATE`), so two concurrent payments cannot both pass the check.

### Scenario 3: Lost update and row locking

Two managers add hours to the same consultant: A adds 10, B adds 5. Both read 100.

| Run | Mechanism | Final value | Why |
| --- | --- | --- | --- |
| 1 | Plain `SELECT`, then `UPDATE` | 110 (B's +5 lost) | A wrote a value calculated from a stale read |
| 2 | `SELECT ... FOR UPDATE` | 115 (correct) | B blocks on the row lock until A commits, then reads 110 |

Another valid fix is an atomic update: `SET hours_allocated = hours_allocated + 5`.

### Scenario 4: Isolation levels

**Part 1, non-repeatable read.** A compliance report reads the number of compliant controls twice in one transaction. Between the reads, an analyst upgrades ratings and commits.

| Isolation level | First read | Second read | Explanation |
| --- | --- | --- | --- |
| READ COMMITTED | 48 | 62 | Each statement sees a fresh snapshot |
| REPEATABLE READ | 48 | 48 | The whole transaction uses one snapshot |

**Part 2, write skew.** Rule: an engagement must keep at least one analyst. Two managers each check "more than one analyst?" and then remove a *different* analyst. They update different rows, so row locks never conflict.

| Isolation level | Outcome |
| --- | --- |
| REPEATABLE READ | Both commit; 0 analysts remain. The rule is broken. |
| SERIALIZABLE | One transaction fails with `could not serialize access due to read/write dependencies` (SQLSTATE 40001); 1 analyst remains. |

Applications using SERIALIZABLE must catch SQLSTATE 40001 and retry the transaction.

### Scenario 5: Deadlock

Session A locks finding 1 then asks for finding 2. Session B locks finding 2 then asks for finding 1. After `deadlock_timeout` (1 second), PostgreSQL detects the cycle, aborts one session (`ERROR: deadlock detected`) and lets the other finish. To prevent deadlocks, always lock rows in a fixed order, for example `ORDER BY finding_id`.

## 4. ACID summary

| Property | Where it is shown |
| --- | --- |
| Atomicity | Scenario 1 (finding and audit row together); Scenario 2 Part A (all or nothing) |
| Consistency | Scenario 2 (trigger rule); Scenario 4 Part 2 (business rule kept only under SERIALIZABLE) |
| Isolation | Scenarios 3 and 4 (locks and snapshot levels) |
| Durability | Scenario 1 (committed change still there in a new session; `audit_log` timestamp) |

## 5. Screenshots for the LMS

Logs prove the results, but the brief also asks for screenshots. For Scenario 3 or 4, run the steps by hand in **two terminal windows side by side** and take one screenshot:

| Step | Terminal A | Terminal B |
| --- | --- | --- |
| 1 | `BEGIN;` | |
| 2 | `SELECT hours_allocated FROM ead.engagement_staff WHERE engagement_id = 1 AND role_on_engagement = 'Engagement lead' FOR UPDATE;` | |
| 3 | | `BEGIN;` |
| 4 | | Same `SELECT ... FOR UPDATE` (it hangs: waiting for the lock) |
| 5 | `UPDATE ead.engagement_staff SET hours_allocated = hours_allocated + 10 WHERE engagement_id = 1 AND role_on_engagement = 'Engagement lead';` | still waiting |
| 6 | `COMMIT;` | returns immediately with the new value |
| 7 | | `UPDATE ... + 5; COMMIT;` |

While B is waiting, a third window can show the lock:

```sql
SELECT pid, state, wait_event_type, wait_event, left(query, 60)
FROM pg_stat_activity WHERE datname = 'ead';
```

## 6. Evidence checklist

- [ ] `output/01` to `output/05` logs committed
- [ ] Two-terminal screenshot of the lock wait (section 5)
- [ ] Screenshot of the SERIALIZABLE error from Scenario 4
- [ ] Screenshot of the deadlock error from Scenario 5
