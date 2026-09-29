# PennySprout Product Requirements Document

## 1. Product Summary

PennySprout is a family habit-and-pocket-money app for children and teenagers. It helps a child complete useful tasks, earn rewards, understand saving and spending, and gradually build money-management habits with family oversight.

The first beta household contains four users:
- Gagan: child
- Mom: parent verifier
- Dad: parent verifier
- Sister: admin and financial approver

The product must later support multiple independent households.

## 2. Core Workflow

### Reward workflow

1. A task is active.
2. Gagan, Mom, or Dad can mark the task completed.
3. Mom or Dad may optionally verify the completion.
4. The completion moves to Admin approval.
5. Sister/Admin approves, edits the approved reward if necessary, or rejects.
6. Only an approved completion creates an earning ledger entry.

**Parent verification is optional. Admin reward approval is mandatory.**

### Task proposal workflow

1. Gagan proposes a new task or a change to an existing task.
2. The proposal contains task details and optionally a suggested reward.
3. Sister/Admin reviews it.
4. Admin may approve as-is, modify and approve, or reject.
5. Approved changes become active.

## 3. Goals

- Make useful routines motivating.
- Teach the child how earnings accumulate.
- Teach the difference between needs and wants.
- Encourage saving toward goals.
- Give the child autonomy without allowing self-created money.
- Keep all financially meaningful changes auditable.
- Avoid excessive approval friction for small daily habits.

## 4. Non-goals for MVP

PennySprout will not:
- transfer money through UPI or banks
- store actual money
- offer investment products
- provide loans, credit, interest or financial advice
- connect to bank accounts
- allow parent verification to directly credit rewards

## 5. Personas

### Child
Can complete tasks, propose tasks, manage personal goals and record expenses.

### Parent
Can observe, mark completion and optionally verify completion. Cannot create financial transactions.

### Admin
Owns the household configuration, reward approval, task approval, payout recording and correction powers.

## 6. Functional Requirements

### Authentication and Household
- Users sign in with their own username and password; internal synthetic Auth addresses are never exposed.
- Admin provisions accounts and temporary passwords; first login requires a password change.
- Each user belongs to a household.
- Household data must not be visible across households.
- Each member has exactly one household role for MVP: CHILD, PARENT, ADMIN.
- Admin can invite or manage household members.

### Tasks
Each task supports:
- title
- description
- category
- reward amount
- recurrence
- active/inactive state
- optional daily/weekly completion limits
- display-only streak eligibility
- created-by and approved-by audit metadata

Recurrence options for MVP:
- one-time
- daily
- selected weekdays
- weekly

### Completion
- Child, parent or admin may mark a task completed.
- Completion stores who marked it and when.
- Duplicate completions outside configured recurrence/limits are blocked.
- Parent verification is optional.
- Verification stores verifier and timestamp.
- Admin may approve or reject.
- Admin may adjust the final approved reward before approval.
- Approval is idempotent and may never create duplicate reward credits.

### Task Proposals
Child can:
- propose a new task
- propose editing a task
- propose deactivating a task
- suggest a reward amount

Admin can:
- approve
- edit and approve
- reject

### Wallet and Ledger

The financial source of truth is an immutable ledger.

Ledger transaction types:
- TASK_REWARD
- EXPENSE / EXPENSE_REVERSAL
- SAVINGS_DEPOSIT / SAVINGS_WITHDRAWAL
- PAYOUT / PAYOUT_REVERSAL
- ADJUSTMENT

Each transaction creates signed postings to the separate SPENDABLE, SAVINGS, and/or UNPAID_EARNINGS balance buckets. The exact rules are defined in `docs/FINANCIAL_MODEL.md`.

Definitions:
- **Spendable balance:** approved rewards minus expenses and savings allocations, adjusted by auditable corrections.
- **Savings balance:** net amount allocated into savings.
- **Payout recorded:** records real-world cash/UPI already handed to the child. It does not create earnings.
- **Unpaid earnings:** total approved earnings minus payouts recorded, useful for Admin to know how much is still physically owed.

Admin is the only role that can create PAYOUT or ADJUSTMENT transactions.

### Expenses
Child can record:
- amount
- description
- category
- Need or Want
- date

For MVP, an expense immediately affects the child's virtual spendable balance. Editing or deleting a posted expense requires Admin approval.

### Savings
- Child can transfer available virtual balance into savings.
- Child can request a savings withdrawal.
- Admin approves withdrawal before balance is returned to spendable funds.
- Automatic savings splitting is not part of the approved beta scope.

### Savings Goals
Child can:
- create a goal
- set name and target amount
- update target
- see progress

Goal deletion should require Admin approval to preserve learning history.

### Streaks
- Streaks are computed from eligible recurring tasks.
- Beta streaks are display-only. Monetary streak bonus configuration and posting are deferred.

### Reports
Child, parent and admin can view:
- earnings by period
- expense totals
- Need vs Want breakdown
- savings amount
- savings-goal progress
- task completion history

Admin additionally sees:
- pending approvals
- payouts due
- payout history
- adjustments

### Notifications
Useful notifications:
- Admin: completion awaiting approval
- Admin: new/edited task proposal
- Child: reward approved/rejected
- Child: task proposal approved/rejected
- Beta sends transactional decision/action notifications only; daily reminders are deferred.

Notifications must not be required for core workflow to function.

## 7. Business Rules

- A child must never be able to directly credit their wallet.
- A parent must never be able to directly credit the wallet.
- Parent verification never bypasses Admin approval.
- Parent verification is not required for Admin approval.
- An Admin can approve a completion even when the child marked it themselves.
- Approved reward amount may differ from task default but the difference must be captured in audit metadata.
- Financial records should be append-only; corrections use adjustment entries rather than destructive edits.
- All currency values are stored as integer minor units, never floating-point.
- Household currency for first beta is INR.
- Time-sensitive task rules use the household timezone.

## 8. Beta Success Criteria

The Gagan beta is successful if:
- the family can use it for at least 30 days without ledger inconsistencies
- no user can perform a financially unauthorized action
- routine task completion takes only a few taps
- Admin can understand pending approvals at a glance
- Gagan can explain his earned, spent and saved amounts using the app
- financial history remains understandable after edits, rejections and payouts

## 9. Future Ideas

Future ideas are not approved scope. Any idea that introduces a fee, subscription, payment method or billable provider requires a new explicit owner decision under `ZERO_COST_OPERATIONS.md`.

Not part of MVP:
- multiple children per family
- badges and levels
- allowance schedules
- family challenges
- photo proof
- QR-based rewards
- bank/UPI integrations
- parental controls for spend requests
- family subscription
- teacher/coach role
