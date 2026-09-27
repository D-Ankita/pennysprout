# PennySprout Implementation Plan

The goal of this plan is to eliminate avoidable implementation-time product decisions.

## Phase 0: Repository Foundation

Deliverables:
- Expo + TypeScript project
- Expo Router
- linting and formatting
- unit-test setup
- environment-variable strategy
- CI for lint, typecheck and tests
- README developer setup

Definition of done:
- app launches locally
- CI passes from clean checkout
- no secrets committed

## Phase 1: Supabase Foundation

Deliverables:
- Supabase local/project setup
- database migrations
- schema contract tests for constraints and grants
- Auth integration
- household, profile and membership schema
- role enum
- base RLS policies
- seed script for beta household

Seed roles:
- Gagan -> CHILD
- Mom -> PARENT
- Dad -> PARENT
- Sister -> ADMIN

Definition of done:
- all four beta users can sign in
- each sees only the beta household
- unauthorized cross-role writes fail at backend
- `0001_initial_schema.sql` applies cleanly to a fresh local database

## Phase 2: Task Management

Deliverables:
- tasks schema
- recurrence model
- Admin task CRUD
- Child task proposal flow
- Admin proposal approval/rejection
- task list screens by role

Definition of done:
- Admin can create task directly
- Child can only propose
- approved proposal becomes active
- parent cannot create/edit tasks

## Phase 3: Completion and Verification

Deliverables:
- task completion records
- deterministic household-timezone occurrence keys
- mark-complete UX
- optional Parent verification
- Admin approval inbox
- rejection flow
- reward override on approval

Definition of done:
- Child, Parent and Admin can mark completion
- Parent verification is optional
- unverified completion can still be Admin approved
- verification alone never creates money

## Phase 4: Ledger and Wallet

Deliverables:
- append-only ledger
- transaction headers plus signed balance-bucket postings
- Admin approve-completion transaction
- wallet projections
- earnings history
- payout recording
- unpaid earnings calculation

Definition of done:
- one approved completion creates exactly one TASK_REWARD transaction
- repeat approval cannot duplicate reward
- Child/Parent cannot create reward/payout entries
- payout is distinct from earning
- balances reconcile from ledger alone
- concurrent financial commands cannot make spendable or savings negative

## Phase 5: Expenses and Savings

Deliverables:
- expense entry
- Need/Want categorization
- edit/delete request mechanism
- spendable-to-savings transfer
- savings withdrawal request and Admin approval
- savings balances

Definition of done:
- Child can understand spendable vs savings
- destructive financial edits are not allowed
- corrections remain auditable

## Phase 6: Goals, Streaks and Reports

Deliverables:
- savings goals
- streak calculation
- monthly report
- Need vs Want analytics
- completion statistics
- Admin payout report

Automated monetary streak bonuses may be deferred until core ledger beta is stable. Display-only streaks should ship first if needed.

## Phase 7: Notifications and UX Polish

Deliverables:
- push notification registration
- Admin approval notifications
- Child approval-result notifications
- empty/loading/error states
- accessibility pass
- mobile responsive/touch usability
- app icon/splash once brand is locked

## Phase 8: Beta Hardening

Test with Gagan's household.

Run scenarios:
- Child self-marks completion
- Parent marks completion
- Parent verifies / does not verify
- Admin modifies reward during approval
- duplicate approval attempt
- rejected completion
- expense then savings transfer
- savings withdrawal
- partial payout
- payout greater than unpaid amount warning
- task proposal edit and rejection
- recurrence boundary around midnight
- temporary network failure during approval

Beta duration target: 30 days.

Track:
- confusing screens
- excessive taps
- reward disputes
- money mismatch
- duplicate entries
- missed notifications
- habits users stop engaging with

## Phase 9: Public Release Preparation

Before public Play Store launch:
- official PennySprout trademark clearance
- privacy policy
- terms
- support/contact page
- age/child-data compliance review
- Play Console disclosures and Data Safety form
- production analytics/crash reporting
- production backups
- account deletion flow
- secure invitation/onboarding
- domain decision
- Play Store screenshots and listing assets

## Engineering Rules

1. Do not implement wallet balance as a mutable column.
2. Do not let UI role checks substitute for backend authorization.
3. Do not allow task approval and ledger insertion as separate non-atomic client writes.
4. Do not delete financial history to fix mistakes.
5. Do not add payment integrations during beta.
6. All schema changes go through migrations.
7. Any change to locked product semantics must update DECISIONS.md.
