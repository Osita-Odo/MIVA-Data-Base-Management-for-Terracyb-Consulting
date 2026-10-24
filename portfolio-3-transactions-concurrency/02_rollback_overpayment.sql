-- =====================================================================
-- Scenario 2: ROLLBACK and SAVEPOINT. A payment that would exceed the
-- invoice is rejected by trg_payment_within_invoice.
--   Part A: the error aborts the whole transaction, then ROLLBACK.
--   Part B: a SAVEPOINT keeps the valid first payment and discards only
--           the invalid second one.
-- Run: psql -d ead -f 02_rollback_overpayment.sql
-- =====================================================================
SET search_path TO ead;
\set ON_ERROR_STOP off

-- Target: the newest unpaid invoice
SELECT invoice_id AS inv, amount_ngn AS amt FROM invoice
WHERE status = 'issued' ORDER BY invoice_id DESC LIMIT 1 \gset
\echo '>>> Target invoice:' :inv 'amount NGN' :amt

\echo '>>> Before:'
SELECT i.invoice_id, i.amount_ngn, i.status, COALESCE(sum(p.amount_ngn), 0) AS paid
FROM invoice i LEFT JOIN payment p ON p.invoice_id = i.invoice_id
WHERE i.invoice_id = :inv GROUP BY i.invoice_id;

\echo ''
\echo '=== Part A: one transaction, second payment too large, ROLLBACK ==='
BEGIN;
    INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
    VALUES (:inv, round(:amt / 2, 2), CURRENT_DATE, 'bank_transfer');
    \echo '>>> First payment accepted inside the transaction'

    INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
    VALUES (:inv, :amt, CURRENT_DATE, 'bank_transfer');      -- exceeds the invoice: ERROR

    \echo '>>> The transaction is now aborted, so even a SELECT fails:'
    SELECT 1;
ROLLBACK;

\echo '>>> After ROLLBACK: nothing was saved, not even the valid first payment'
SELECT i.invoice_id, i.status, COALESCE(sum(p.amount_ngn), 0) AS paid
FROM invoice i LEFT JOIN payment p ON p.invoice_id = i.invoice_id
WHERE i.invoice_id = :inv GROUP BY i.invoice_id;

\echo ''
\echo '=== Part B: same steps with a SAVEPOINT ==='
BEGIN;
    INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
    VALUES (:inv, round(:amt / 2, 2), CURRENT_DATE, 'bank_transfer');
    SAVEPOINT before_second_payment;

    INSERT INTO payment (invoice_id, amount_ngn, paid_on, method)
    VALUES (:inv, :amt, CURRENT_DATE, 'bank_transfer');      -- ERROR again

    ROLLBACK TO SAVEPOINT before_second_payment;
    \echo '>>> Rolled back to the savepoint; the transaction is usable again'
COMMIT;

\echo '>>> After COMMIT: half paid, status part_paid'
SELECT i.invoice_id, i.amount_ngn, i.status, COALESCE(sum(p.amount_ngn), 0) AS paid
FROM invoice i LEFT JOIN payment p ON p.invoice_id = i.invoice_id
WHERE i.invoice_id = :inv GROUP BY i.invoice_id;
