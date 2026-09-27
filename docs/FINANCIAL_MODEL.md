# PennySprout Financial Model and Flows

## 1. Purpose

PennySprout tracks three different questions. They must not be collapsed into one balance:

1. **Spendable:** how much virtual money the Child may allocate or record as spent.
2. **Savings:** how much virtual money the Child deliberately set aside.
3. **Unpaid earnings:** how much earned value Admin has not yet recorded as physically paid in cash/UPI.

The first two teach budgeting. The third is a family settlement figure. A physical payout does not erase the Child's virtual budgeting history.

## 2. Source of truth

`ledger_transactions` stores the immutable business event. `ledger_postings` stores its signed effects on balance buckets. No balance column is editable.

| Transaction kind | SPENDABLE | SAVINGS | UNPAID_EARNINGS |
|---|---:|---:|---:|
| `TASK_REWARD` | `+amount` | — | `+amount` |
| `EXPENSE` | `-amount` | — | — |
| `EXPENSE_REVERSAL` | `+original amount` | — | — |
| `SAVINGS_DEPOSIT` | `-amount` | `+amount` | — |
| `SAVINGS_WITHDRAWAL` | `+amount` | `-amount` | — |
| `PAYOUT` | — | — | `-amount` |
| `PAYOUT_REVERSAL` | — | — | `+amount` |
| `ADJUSTMENT` | explicit signed posting(s) | explicit | explicit |

Amounts are signed integers in paise. Transaction business amounts remain positive; posting direction carries the sign.

A zero-value approved reward creates an auditable `TASK_REWARD` transaction with business amount zero and no postings. Every other financial transaction has a positive business amount.

## 3. Derived balances

For each `(household_id, child_user_id)`:

```text
spendable_balance = sum(postings where bucket = SPENDABLE)
savings_balance = sum(postings where bucket = SAVINGS)
unpaid_earnings = sum(postings where bucket = UNPAID_EARNINGS)
total_earned = sum(TASK_REWARD business amounts)
total_expenses = sum(effective EXPENSE business amounts after reversals)
total_paid_out = sum(PAYOUT amounts) - sum(PAYOUT_REVERSAL amounts)
```

Balances must be read from the database projection. Clients may format values but must not independently recreate accounting rules.

## 4. Examples

Starting from zero:

1. Admin approves a ₹100 reward: spendable ₹100, savings ₹0, unpaid ₹100.
2. Child saves ₹30: spendable ₹70, savings ₹30, unpaid ₹100.
3. Child records a ₹20 Want expense: spendable ₹50, savings ₹30, unpaid ₹100.
4. Admin records ₹60 cash paid: spendable ₹50, savings ₹30, unpaid ₹40.

The values differ intentionally. The app should label them plainly instead of presenting a single ambiguous "wallet balance."

## 5. Expense flow

### Create

- Require amount greater than zero, expense date, description, category, and `NEED` or `WANT`.
- Reject if spendable balance would become negative.
- Store dates as `DATE` for the user's chosen expense date and `TIMESTAMPTZ` for audit creation time.
- Post through a server function; direct ledger writes are denied.

### Correct

- Child submits a pending correction request and explanation.
- `VOID` requests reverse the full original posting after Admin approval.
- `REPLACE` requests reverse the original and post the complete replacement atomically.
- The replacement is checked against the balance after reversal.
- Rejection changes no money.
- UI shows original, correction, reviewer, and resulting effective value.

## 6. Savings flow

### Deposit

- Child chooses a positive amount no greater than spendable.
- Server locks the Child's financial scope, rechecks the balance, and posts the two-sided bucket transfer.
- Optional goal allocation is metadata/reporting and cannot exceed the savings deposit.

### Withdraw

- Child creates a request with amount and reason.
- No balance changes while pending.
- Admin reviews and may approve or reject; Admin cannot silently change the requested amount. A different amount requires rejection and a new request.
- Approval rechecks savings and posts both bucket effects atomically.

## 7. Payout flow

- Admin records amount, method (`CASH`, `UPI`, or `OTHER`), paid-at time, and optional note/reference.
- The payout reduces only unpaid earnings.
- A payout cannot exceed unpaid earnings.
- A mistaken payout is corrected by a linked reversal; the original is retained.

## 8. Adjustments

Adjustments are exceptional Admin-only corrections, never a general editing tool.

Required fields:

- affected bucket;
- signed amount;
- human-readable reason;
- Admin actor and timestamp;
- optional link to an incident or prior transaction.

The UI must warn clearly and preview resulting balances. Adjustments that would make spendable or savings negative are rejected. All adjustments appear in reports and audit history.

## 9. Invariants

1. Child and Parent have no direct insert/update/delete permission on ledger tables.
2. Parent actions never call a financial posting function.
3. Each approved completion has exactly one `TASK_REWARD` transaction.
4. Each approved withdrawal request has exactly one `SAVINGS_WITHDRAWAL` transaction.
5. Reversals point to one original transaction, and an original can be reversed at most once per reversal kind.
6. `SPENDABLE` and `SAVINGS` never become negative.
7. `UNPAID_EARNINGS` never becomes negative through payout; only an explicit justified adjustment can represent an exceptional settlement correction.
8. Financial rows are immutable after insertion; corrections append rows.
9. All values use the household currency and integer minor units.

## 10. Required financial tests

- reward approval posts both expected buckets once;
- parent verification produces zero postings;
- repeat approval with the same idempotency key returns the original result;
- concurrent approvals cannot duplicate a reward;
- concurrent expenses cannot overspend;
- savings transfer sums to zero across virtual buckets;
- insufficient savings leaves a withdrawal pending;
- expense reversal plus replacement gives the expected net balance;
- payout changes unpaid earnings only;
- Child/Parent direct ledger writes fail;
- cross-household reads and function calls fail.
