# PennySprout Technical Design

## 1. Architecture

### Mobile client
- React Native with Expo
- TypeScript
- Expo Router
- TanStack Query for server state
- React Hook Form + Zod for forms and validation

### Backend
- Supabase Auth
- PostgreSQL
- Row Level Security
- Supabase Edge Functions only where privileged transactional logic is required

### Notifications
- Expo push notifications
- Notification dispatch triggered from trusted server-side actions

## 2. Security Boundary

The client is untrusted.

All sensitive permissions must be enforced by:
- database constraints
- RLS policies
- privileged database functions or Edge Functions for financial operations

Never rely only on disabled buttons or hidden screens.

## 3. Core Data Model

The authoritative table, enum, constraint, index, grant, and RLS definitions are in [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) and the executable migration at [`supabase/migrations/0001_initial_schema.sql`](../supabase/migrations/0001_initial_schema.sql).

The main aggregates are:

- identity and tenancy: `profiles`, `households`, `household_members`;
- work: `tasks`, `task_schedule_weekdays`, `task_proposals`, `task_completions`, `completion_verifications`;
- finance: `ledger_transactions`, `ledger_postings`, `expense_correction_requests`, `savings_withdrawal_requests`;
- learning: `savings_goals`, `savings_goal_allocations`;
- reliability: `idempotency_keys`, `audit_events`, `notification_outbox`, `push_tokens`.

The normative transitions are in [STATE_MACHINES.md](STATE_MACHINES.md). Financial posting rules are in [FINANCIAL_MODEL.md](FINANCIAL_MODEL.md).

## 4. Transactional Operations

These actions should execute atomically server-side.

### approve_completion(completion_id, approved_reward_minor, note, idempotency_key)
Checks:
- caller is ADMIN in same household
- completion is PENDING_APPROVAL
- amount >= 0
- no existing TASK_REWARD transaction references this completion

Transaction:
1. mark completion APPROVED
2. store review fields
3. insert one TASK_REWARD transaction
4. insert positive SPENDABLE and UNPAID_EARNINGS postings
5. insert audit event

Idempotency must prevent duplicate earnings.

### reject_completion(completion_id, note)
- Admin only
- changes pending completion to REJECTED
- creates no financial entry

### record_payout(child_id, amount_minor, method, paid_at, note, idempotency_key)
- Admin only
- amount > 0
- insert one PAYOUT transaction and a negative UNPAID_EARNINGS posting
- reject amounts greater than unpaid earnings; exceptional overpayment requires a separate explained adjustment

### request_savings_withdrawal / decide_savings_withdrawal
- Child creates pending request
- Admin approves/rejects
- approval creates appropriate ledger movement

## 5. Derived Financial Views

### spendable_balance
Sum of `SPENDABLE` postings.

### savings_balance
Sum of `SAVINGS` postings.

### total_earned
Sum of `TASK_REWARD` transaction amounts.

### total_expenses
Absolute sum of EXPENSE entries.

### total_paid_out
Net `PAYOUT` minus `PAYOUT_REVERSAL` transaction amounts.

### unpaid_earnings
Sum of `UNPAID_EARNINGS` postings.

This is an administrative settlement figure and is separate from spendable balance.

## 6. RLS Strategy

Every household-owned table contains household_id.

Policies should ensure:
- active household membership is required for SELECT
- CHILD can invoke allowed completion, proposal, expense, savings, and goal commands for self
- PARENT can invoke completion and verification commands but no financial posting commands
- ADMIN receives required mutation permissions
- direct client writes to all ledger transactions and postings are blocked
- privileged financial operations go through trusted RPC/Edge Function paths

## 7. Screens

### Shared
- Sign in
- Household switcher if multi-household is added later
- Notifications/activity

### Child
- Home / Today
- Task details
- Propose task/edit
- Wallet
- Expenses
- Savings
- Goals
- Reports
- History

### Parent
- Home / Today's tasks
- Completion history
- Verify completion
- Wallet/report read-only views

### Admin
- Dashboard
- Pending completion approvals
- Task proposals
- Tasks management
- Wallet / payout management
- Household users
- Rules/settings
- Reports
- Audit/history

## 8. Offline and Sync

MVP should tolerate temporary loss of connectivity for viewing cached data.

Financial approvals and payout creation must require server confirmation before UI treats them as final.

Do not optimistically display money as permanently credited before server success.

## 9. Observability

Capture:
- auth failures
- failed privileged transactions
- duplicate/idempotency violations
- notification failures
- client crashes

Never log authentication tokens or sensitive secrets.

## 10. Testing

Required test layers:
- unit tests for money calculations and recurrence rules
- integration tests for database/RLS authorization
- transaction tests for duplicate approval prevention
- UI tests for role-based flows
- end-to-end happy paths for Child, Parent and Admin

Highest priority security tests:
- Child cannot insert ledger transactions or postings
- Parent cannot insert ledger transactions or postings
- Parent verification cannot mutate wallet
- Child cannot approve completion
- cross-household reads/writes fail
- repeated Admin approval credits only once
