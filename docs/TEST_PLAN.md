# PennySprout Test Plan

Status: **REQUIRED QUALITY GATES**

Tests prove observable behavior and authorization. Coverage alone does not replace required scenarios.

## 1. Test stack

- Jest through `jest-expo` for domain and component tests.
- React Native Testing Library for accessible UI behavior.
- pgTAP/Supabase database tests for constraints, RLS and RPCs.
- Maestro for Android emulator/physical-device critical journeys.
- GitHub Actions with Node 24 and a local Supabase stack.

Fixtures use generic fictional data except the documented beta seed. Tests control time explicitly and never depend on the machine timezone.

## 2. Coverage thresholds

- Overall statements: 80% minimum.
- Overall branches: 75% minimum.
- Recurrence, role-capability helpers, posting builders and financial validation: 100% branch coverage.
- New defect fixes require a failing regression test before or with the fix.

## 3. Required domain cases

### Recurrence

- one-time availability and automatic inactivation after approval;
- daily local-midnight boundary;
- every ISO weekday individually and combined selections;
- weekly Monday/Sunday boundary;
- task created mid-occurrence;
- future-only recurrence edits;
- one-through-five completion limits;
- rejected resubmission and three-attempt cap;
- UTC timestamps around local date boundaries.

### Finance

- task reward posts equal positive Spendable and Unpaid Earnings effects once;
- zero reward approval creates an auditable zero-reward decision without invalid zero postings;
- expense reduces Spendable only;
- expense reversal and replacement net correctly;
- savings deposit/withdrawal transfer equal and opposite virtual buckets;
- payout changes Unpaid Earnings only;
- payout reversal restores it;
- adjustment affects only declared bucket;
- concurrent expenses/deposits cannot overspend;
- all projections reconcile from postings.

## 4. Authorization matrix

Test each Child, Parent and Admin capability from `RBAC.md`, including denial. Mandatory adversarial cases:

- unauthenticated access;
- disabled membership;
- unrelated household;
- forged household/child IDs;
- Child or Parent ledger insertion;
- Child approval/rejection;
- Parent task/expense/savings/payout mutation;
- modification/deletion of ledger and audit history;
- cross-child references within a future multi-child household;
- direct invocation of service-only authentication data/functions;
- missing, mismatched, malformed, revoked or 30-day-idle app sessions (lazy rejection through RLS and RPC helpers);
- client read or direct write of `private.app_sessions` or `private.client_error_reports`.

### Session and crash-report cases

- the gateway creates an app session at sign-in and a session ID cannot be claimed by another user or revived after revocation;
- 29 days 23 hours idle is accepted and exactly 30 days is rejected; `touch_app_session` refreshes activity or records `INACTIVITY`;
- password change revokes other sessions only; Admin reset and disablement revoke all; sign-out ends the current session;
- the client signs out from `expo-secure-store` state after 30 inactive days without a network call;
- crash reports accept only allow-listed fields, drop unsafe stacks, derive household server-side, enforce per-device/per-user limits and delete rows older than 30 days;
- reporting failures never reject or change product behavior.

## 5. State and idempotency cases

- every allowed transition succeeds once;
- every unlisted transition fails without side effects;
- same key and payload replays the same result;
- same key and different payload conflicts;
- concurrent approval creates one reward;
- stale proposal cannot mutate task;
- notification failure does not roll back decision;
- database exception rolls back state, postings, audit and outbox together.

## 6. Component cases

Every screen covers loading, populated, empty, refreshing, retryable error, offline cache, permission denied and submitting states. Forms cover required fields, boundaries, server field errors and double taps. Tests query by accessible roles/labels rather than implementation IDs where practical.

## 7. End-to-end journeys

1. Admin creates Child/Parents; each changes temporary password.
2. Child completes; Parent optionally verifies; Admin approves; balances update on both devices.
3. Admin approves without verification.
4. Admin changes reward with reason.
5. Admin rejects; Child resubmits; attempt cap holds.
6. Child proposes task; Admin edits/approves; stale proposal fails safely.
7. Child records expense; requests replacement; Admin approves.
8. Child deposits savings; requests withdrawal; Admin approves.
9. Child requests goal archive; Admin decides.
10. Admin records partial payout and reversal.
11. Network interruption followed by idempotent retry.
12. Disabled account loses access.
13. Push opens the correct detail and stale notification refetches current state.

## 8. CI required checks

`npm ci`, format check, ESLint, strict typecheck, unit/component tests with coverage, Supabase fresh reset, database/RLS tests, migration lint, `npx expo-doctor`, release export, secret scan, and dependency/license audit. Required checks must pass before merge.

## 9. Manual device matrix

Before beta, test at least one lower-spec Android 9–11 device and one current Android device. Verify installation, upgrade, secure session persistence, text scaling, notification permission/receipt/deep link, offline labels, reconnection, and all three roles. Passing emulator tests is not physical-device readiness.
