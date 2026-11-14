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
| Output evidence | Logs of every run | [`output/`](output) |
| Two-terminal demonstration | Manual lock wait in two sessions, plus a monitor | [`session_a.sql`](session_a.sql), [`session_b.sql`](session_b.sql), [`monitor.sql`](monitor.sql) |
| Screenshots | All five scenarios | Section 5, [`screenshots/`](screenshots) |

## Key decisions and reasons

Full register with alternatives: [docs/design-decisions.md](../docs/design-decisions.md).

| Decision | Reason | ID |
| --- | --- | --- |
| Scenarios built on TerraCyber operations (closing findings, payments, staffing, compliance reports) | Each brief requirement is evidenced with a realistic case rather than an abstract example | D44 |
| Two scripted sessions timed with `pg_sleep` | Forces the same interleaving every time, so the logs are reproducible evidence | D45 |
| `SELECT ... FOR UPDATE` to fix the lost update | The manager reads the hours before deciding; a row lock protects exactly this read-decide-write pattern | D46 |
| SERIALIZABLE to stop write skew | The two managers update different rows, so ordinary row locks never conflict; SERIALIZABLE detects the pattern anyway | D47 |
| Deadlock scenario with ordered locking as the fix | Row locks (D46) create deadlock risk; the scenario shows both detection and prevention | D48 |
| Scripts restore the rows they change | Scenarios can be rerun in any order with the same results | D49 |

## In plain terms: what a transaction is

A **transaction** groups several changes so they succeed or fail together. The four guarantees are known as **ACID**:

| Property | Meaning |
| --- | --- |
| Atomicity | All changes happen, or none do |
| Consistency | The rules (constraints, triggers) hold before and after |
| Isolation | Users working at the same time do not see each other's half-finished work |
| Durability | Once committed, a change survives a crash |

When two people work on the same data at the same moment, things can go wrong in specific, named ways: a **lost update** (one change overwrites another), a **non-repeatable read** (the same question gives two answers inside one transaction), **write skew** (two changes that are each fine break a rule together) and a **deadlock** (two transactions each wait for the other forever). Each scenario below makes one of these happen on purpose, then shows the mechanism that prevents it.

| Scenario | What happens | Result and lesson |
| --- | --- | --- |
| 1. COMMIT | A finding is closed; the audit trigger writes a log row in the same transaction | Both changes are saved together, or neither |
| 2. ROLLBACK and SAVEPOINT | A valid payment, then one that would overpay the invoice | Without a savepoint, ROLLBACK undoes both; with one, only the bad step is undone and the invoice shows "part paid" |
| 3. Lost update | Two managers add 10 and 5 hours to the same consultant at the same moment | Without a lock the total is 110 (one change lost); with `SELECT ... FOR UPDATE` it is the correct 115 |
| 4. Isolation levels | A report counts compliant controls twice while an analyst updates them; two managers each remove a different analyst | READ COMMITTED gave 52 then 68; REPEATABLE READ gave 52 both times. Only SERIALIZABLE stopped the managers leaving an engagement with no analyst |
| 5. Deadlock | Two analysts lock the same two findings in opposite order | PostgreSQL detects the cycle and cancels one; prevention: always lock rows in the same order |

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
| READ COMMITTED | 52 | 68 | Each statement sees a fresh snapshot |
| REPEATABLE READ | 52 | 52 | The whole transaction uses one snapshot |

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

## 5. Screenshots

The screenshots below were captured from a test run on 14 November 2026 (PostgreSQL 16.15). Each one shows the command that was run and its unedited output; the full logs are in [`output/`](output).

### 5.1 Two terminals: a row lock in action

This is the brief's "two terminals side by side" evidence. It was run live with two real `psql` sessions using [`session_a.sql`](session_a.sql) and [`session_b.sql`](session_b.sql):

1. In terminal A, start `psql -d ead -a -f session_a.sql`. Manager A locks the row with `SELECT ... FOR UPDATE` and holds the lock for 4 seconds.
2. Within those 4 seconds, in terminal B, start `psql -d ead -a -f session_b.sql`. Manager B asks for the same row and **waits**.
3. When A commits, B continues immediately and reads A's new value, so neither change is lost.
4. To repeat the demo, run the reset line at the end of `session_b.sql`.

![Two terminals: B waits for A's row lock](screenshots/01-lock-wait-two-terminals.png)

B asked for the row at 21:12:36 but only got it at 21:12:39, the moment A committed. B then read 60.0 (A's value, not the stale 50.0), so the final total is 50 + 10 + 5 = 65.0.

While B was waiting, a third terminal ran [`monitor.sql`](monitor.sql). It shows B blocked on a `Lock` of type `transactionid`, which is A's open transaction:

![pg_stat_activity shows B waiting on a lock](screenshots/02-lock-wait-monitor.png)

### 5.2 The scripted scenarios

**Scenario 3, lost update.** Without a lock the total is 110.0 (B's +5 is overwritten by A); with `FOR UPDATE` it is 115.0:

![Lost update and its fix](screenshots/03-lost-update-script.png)

**Scenario 4, Part 1, non-repeatable read.** Under READ COMMITTED the report reads 52 and then 68 compliant controls inside one transaction; under REPEATABLE READ it reads 52 both times:

![Non-repeatable read under READ COMMITTED vs REPEATABLE READ](screenshots/04-isolation-non-repeatable-read.png)

**Scenario 4, Part 2, write skew.** Under REPEATABLE READ both managers remove an analyst and 0 remain. Under SERIALIZABLE, PostgreSQL cancels Manager B with SQLSTATE 40001 ("could not serialize access") and 1 analyst remains:

![Write skew prevented by SERIALIZABLE](screenshots/05-serializable-write-skew.png)

**Scenario 5, deadlock.** Session A is chosen as the deadlock victim and rolled back; session B completes:

![Deadlock detected and resolved](screenshots/06-deadlock.png)

## 6. Evidence checklist

- [x] `output/01` to `output/05` logs committed (test run)
- [x] Two-terminal screenshot of the lock wait ([section 5.1](#51-two-terminals-a-row-lock-in-action))
- [x] Screenshot of the SERIALIZABLE error from Scenario 4 ([screenshot](screenshots/05-serializable-write-skew.png))
- [x] Screenshot of the deadlock error from Scenario 5 ([screenshot](screenshots/06-deadlock.png))
- [ ] Re-run the two-terminal demo yourself, in two real terminal windows, and replace the test-run captures with your own
