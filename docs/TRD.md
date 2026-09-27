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

### households
- id UUID PK
- name TEXT
- currency_code TEXT default INR
- timezone TEXT default Asia/Kolkata
- created_at TIMESTAMPTZ

### profiles
- id UUID PK referencing auth.users
- display_name TEXT
- created_at TIMESTAMPTZ

### household_members
- household_id UUID FK
- user_id UUID FK
- role ENUM(CHILD, PARENT, ADMIN)
- status ENUM(INVITED, ACTIVE, DISABLED)
- joined_at TIMESTAMPTZ
- unique(household_id, user_id)

### tasks
- id UUID PK
- household_id UUID FK
- title TEXT
- description TEXT nullable
- category TEXT
- reward_minor BIGINT
- recurrence_type ENUM(ONE_TIME, DAILY, WEEKLY, SELECTED_WEEKDAYS)
- recurrence_config JSONB
- completion_limit INTEGER nullable
- is_active BOOLEAN
- created_by UUID
- approved_by UUID nullable
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

### task_proposals
- id UUID PK
- household_id UUID FK
- task_id UUID nullable
- proposal_type ENUM(CREATE, UPDATE, DEACTIVATE)
- payload JSONB
- requested_by UUID
- status ENUM(PENDING, APPROVED, REJECTED)
- reviewed_by UUID nullable
- review_note TEXT nullable
- reviewed_at TIMESTAMPTZ nullable
- created_at TIMESTAMPTZ

### task_completions
- id UUID PK
- household_id UUID FK
- task_id UUID FK
- child_user_id UUID
- marked_by UUID
- completed_at TIMESTAMPTZ
- status ENUM(PENDING_APPROVAL, APPROVED, REJECTED)
- approved_reward_minor BIGINT nullable
- reviewed_by UUID nullable
- review_note TEXT nullable
- reviewed_at TIMESTAMPTZ nullable
- created_at TIMESTAMPTZ

### completion_verifications
- id UUID PK
- completion_id UUID FK
- verifier_user_id UUID
- verified_at TIMESTAMPTZ
- note TEXT nullable
- unique(completion_id, verifier_user_id)

A completion can have zero or more verification records. Verification does not change financial state.

### ledger_entries
- id UUID PK
- household_id UUID FK
- child_user_id UUID
- type ENUM(EARNING, EXPENSE, SAVINGS_TRANSFER_IN, SAVINGS_TRANSFER_OUT, PAYOUT_RECORDED, ADJUSTMENT)
- amount_minor BIGINT
- reference_type TEXT nullable
- reference_id UUID nullable
- description TEXT
- created_by UUID
- created_at TIMESTAMPTZ
- metadata JSONB

Ledger entries are append-only for normal users.

Recommended sign convention:
- EARNING: positive spendable
- EXPENSE: negative spendable
- SAVINGS_TRANSFER_IN: negative spendable and paired positive savings effect
- SAVINGS_TRANSFER_OUT: positive spendable and paired negative savings effect
- PAYOUT_RECORDED: does not affect virtual spendable/savings totals, but reduces unpaid physical payout amount
- ADJUSTMENT: explicit signed correction

For clarity, wallet projections should be implemented in SQL views/functions instead of duplicated client calculations.

### savings_goals
- id UUID PK
- household_id UUID FK
- child_user_id UUID
- name TEXT
- target_minor BIGINT
- status ENUM(ACTIVE, COMPLETED, ARCHIVED)
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

### savings_allocations
Optional if goal-specific allocation is included in MVP:
- goal_id UUID
- ledger_entry_id UUID
- amount_minor BIGINT

### streak_rules
- id UUID PK
- task_id UUID FK
- threshold_count INTEGER
- bonus_minor BIGINT
- is_active BOOLEAN

### audit_events
- id UUID PK
- household_id UUID
- actor_user_id UUID
- event_type TEXT
- entity_type TEXT
- entity_id UUID nullable
- data JSONB
- created_at TIMESTAMPTZ

## 4. Transactional Operations

These actions should execute atomically server-side.

### approve_completion(completion_id, approved_reward_minor, note)
Checks:
- caller is ADMIN in same household
- completion is PENDING_APPROVAL
- amount >= 0
- no existing EARNING ledger entry references this completion

Transaction:
1. mark completion APPROVED
2. store review fields
3. insert EARNING ledger entry
4. insert audit event

Idempotency must prevent duplicate earnings.

### reject_completion(completion_id, note)
- Admin only
- changes pending completion to REJECTED
- creates no financial entry

### record_payout(child_id, amount_minor, method, note)
- Admin only
- amount > 0
- insert PAYOUT_RECORDED
- payout may not exceed configured policy; for MVP warn if larger than unpaid earnings and require explicit confirmation

### request_savings_withdrawal
- Child creates pending request
- Admin approves/rejects
- approval creates appropriate ledger movement

## 5. Derived Financial Views

### spendable_balance
Sum of ledger effects on spendable virtual funds.

### savings_balance
Sum of savings transfer effects.

### total_earned
Sum of EARNING amounts.

### total_expenses
Absolute sum of EXPENSE entries.

### total_paid_out
Sum of PAYOUT_RECORDED amounts.

### unpaid_earnings
total_earned - total_paid_out

This is an administrative settlement figure and is separate from spendable balance.

## 6. RLS Strategy

Every household-owned table contains household_id.

Policies should ensure:
- active household membership is required for SELECT
- CHILD can insert allowed completion/proposal/expense/goal records for self
- PARENT can insert completion and verification records but no ledger entries
- ADMIN receives required mutation permissions
- direct client INSERT into EARNING, PAYOUT_RECORDED and ADJUSTMENT is blocked
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
- Child cannot insert EARNING
- Parent cannot insert EARNING
- Parent verification cannot mutate wallet
- Child cannot approve completion
- cross-household reads/writes fail
- repeated Admin approval credits only once
