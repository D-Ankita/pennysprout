# PennySprout State Machines

This document is the normative workflow contract. Database functions must reject transitions that are not listed here, even if a client attempts them directly.

## 1. Task lifecycle

Tasks use `DRAFT`, `ACTIVE`, and `INACTIVE`.

| From | Action | Actor | To | Side effects |
|---|---|---|---|---|
| none | Admin creates task | Admin | `ACTIVE` or `DRAFT` | Audit event |
| `DRAFT` | Activate | Admin | `ACTIVE` | Audit event |
| `ACTIVE` | Deactivate | Admin | `INACTIVE` | Future completions blocked; history retained |
| `INACTIVE` | Reactivate | Admin | `ACTIVE` | Audit event |
| any | Change task | Admin | same | Increment `version`; old completions keep snapshots |

Tasks are never physically deleted after they have a proposal, completion, or financial reference.

## 2. Task proposal lifecycle

Task proposals use `PENDING`, `APPROVED`, `REJECTED`, and `CANCELLED`.

```text
Child submits -> PENDING -> Admin approves -> APPROVED -> task change applied atomically
                           -> Admin rejects  -> REJECTED
              -> Child cancels              -> CANCELLED
```

Rules:

- Gagan/Child may propose `CREATE`, `UPDATE`, or `DEACTIVATE`.
- The proposal stores a complete validated snapshot of the proposed values, not a free-form patch with arbitrary columns.
- For `UPDATE` and `DEACTIVATE`, `base_task_version` must equal the current task version at review time. If it does not, approval fails with `STALE_PROPOSAL`; Admin must review against the newer task and submit a replacement.
- Only the requesting Child may cancel, and only while pending.
- Only Admin may approve or reject.
- Approval and task mutation are one database transaction.
- Review is terminal and idempotent: retrying the same decision returns the existing outcome; a conflicting second decision fails.

## 3. Task completion and reward lifecycle

Completion status represents Admin's financial decision. Parent verification is separate evidence and is not a completion state.

```text
ACTIVE task occurrence
        |
        | Child, Parent, or Admin marks complete
        v
PENDING_APPROVAL <---- optional Parent/Admin verification record
      |     |
      |     +---- Admin rejects ----> REJECTED (terminal, no money)
      |
      +---------- Admin approves ---> APPROVED (terminal, earning posted once)
```

### Submit completion

Preconditions:

- actor has an active Child, Parent, or Admin membership in the same household;
- target member is an active Child in that household;
- task is `ACTIVE`;
- `completed_at` is not unreasonably in the future;
- server derives the occurrence key using task recurrence plus household timezone;
- the configured completion limit for that occurrence has not been reached.

Atomic effects:

1. Create completion as `PENDING_APPROVAL`.
2. Snapshot task title, reward, task version, and occurrence key.
3. Record actor and audit event.

### Verify completion

- Parent or Admin in the household may verify a pending completion.
- One verification per verifier per completion.
- Verification may add a note but never changes completion status or money.
- Approval does not wait for verification.
- A verification cannot be added after approval or rejection.

### Approve completion

Preconditions:

- actor is Admin in the household;
- completion is `PENDING_APPROVAL`;
- approved reward is a non-negative integer minor-unit amount;
- idempotency key has not been used for a different command.

Atomic effects:

1. Lock the completion row.
2. Set status to `APPROVED` and save reviewer, approved reward, note, and time.
3. Create one `TASK_REWARD` transaction referencing the completion.
4. Post `+approved_reward` to `SPENDABLE`.
5. Post `+approved_reward` to `UNPAID_EARNINGS`.
6. Record audit event.

The unique transaction reference `(TASK_REWARD, completion_id)` prevents duplicate credit. A retry returns the already approved result. A different reward or decision after approval fails.

### Reject completion

Admin sets the pending completion to `REJECTED`, with reviewer, reason, and time. No financial transaction is created. Rejected and approved completions are terminal; reopening requires a new completion and an audit explanation.

## 4. Expense lifecycle

An expense is a posted financial transaction, not a mutable row.

```text
Child/Admin records expense -> POSTED
POSTED -> correction request PENDING -> Admin REJECTS -> original remains effective
                                      -> Admin APPROVES -> reversal posted
                                                           + optional replacement posted
```

- Child or Admin may record an expense for the Child.
- Posting requires sufficient `SPENDABLE` balance.
- The transaction posts a negative amount to `SPENDABLE`.
- Need/Want, category, merchant/description, and expense date are immutable metadata on the posted transaction.
- A Child requests correction with either `VOID` or `REPLACE` and a reason.
- For `REPLACE`, the request contains the entire replacement expense snapshot.
- Admin approval creates an `EXPENSE_REVERSAL` linked to the original, then optionally a new `EXPENSE` linked to the request. The original remains visible.
- Only one approved reversal may exist for an expense.

## 5. Savings lifecycle

### Deposit into savings

Child or Admin may transfer a positive amount up to the Child's current spendable balance.

One `SAVINGS_DEPOSIT` transaction atomically posts:

- negative amount to `SPENDABLE`;
- equal positive amount to `SAVINGS`.

No Admin approval is required.

### Withdrawal from savings

Requests use `PENDING`, `APPROVED`, `REJECTED`, and `CANCELLED`.

```text
Child requests -> PENDING -> Admin approves -> APPROVED + one savings withdrawal transaction
                         -> Admin rejects  -> REJECTED
                -> Child cancels          -> CANCELLED
```

Rules:

- Requesting does not reserve or move money.
- Child may cancel only a pending request.
- Admin approval rechecks the current savings balance under a lock.
- Approval posts a negative amount to `SAVINGS` and an equal positive amount to `SPENDABLE`.
- If funds are no longer sufficient, approval fails and the request remains pending.
- A unique transaction reference to the request prevents a double withdrawal.

## 6. Payout lifecycle

A payout records cash/UPI already handed to the Child outside PennySprout.

- Only Admin may record it.
- It posts a negative amount to `UNPAID_EARNINGS` only.
- It does not change `SPENDABLE` or `SAVINGS`.
- The default rule rejects a payout above unpaid earnings. An intentional overpayment requires an explicit Admin adjustment with a reason, rather than a bypass flag.
- Payout corrections are append-only reversals performed by Admin.

## 7. Concurrency and retry contract

- Every privileged command accepts a client-generated UUID idempotency key.
- Reusing a key for the same command returns the original result.
- Reusing it with different arguments fails.
- Financial commands acquire a transaction-scoped advisory lock for `(household_id, child_user_id)` before checking balances and posting.
- State decisions lock the target row with `FOR UPDATE`.
- The client shows a pending network state until the server confirms success and then invalidates relevant queries.
