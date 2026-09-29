# PennySprout Claude Code Implementation Handoff

## Mission

Implement PennySprout exactly from the locked repository specifications. Product and architecture decisions are already made. Do not substitute libraries, reinterpret money semantics, add deferred features, or begin UI before its backend contract is tested.

## Authority order

If documents appear inconsistent, stop and report the exact conflict. Otherwise use this order:

1. `DECISION_CLOSURE.md`
2. `STATE_MACHINES.md`, `RECURRENCE_RULES.md` and `FINANCIAL_MODEL.md`
3. `API_CONTRACTS.md`, `AUTH_AND_ONBOARDING.md`, `NOTIFICATIONS.md` and `DATABASE_SCHEMA.md`
4. `RBAC.md`
5. `USER_FLOWS_AND_SCREENS.md` and `UI_DESIGN_SYSTEM.md`
6. `DEPENDENCY_PLAN.md`, `TEST_PLAN.md`, `BUILD_AND_RELEASE.md`
7. `PRD.md`, `TRD.md`, `IMPLEMENTATION_PLAN.md`, `README.md`

## Non-negotiable invariants

- Completion → optional Parent verification → mandatory Admin approval → reward.
- Parent never causes a financial posting.
- Client never writes ledger tables.
- Money is integer paise and history is append-only.
- Approval and posting are atomic and idempotent.
- Spendable and Savings never become negative.
- Every row/function is household-authorized server-side.
- UI confirmation never precedes server confirmation for money.
- No AI attribution or co-author metadata.

## Git execution

Keep `Test` as integration/default. Create `ankita/<feature-name>` branches. Use focused PRs; never rewrite shared history. Each PR reports scope, migrations, tests, risks, screenshots for visible UI and remaining external gates.

## Phases

### 0. Repository foundation

Scaffold Expo SDK 57 with Node/npm pins, strict TypeScript, Router, lint/format/test setup, environment validation, CI and developer setup. Preserve all existing docs/migrations. Done when clean checkout installs and all foundation checks run.

### 1. Database and authentication foundation

Initialize Supabase config/seed/tests. Reconcile/apply schema; implement username gateway, account provisioning/reset, forced password change, profiles/memberships and RLS. Done when four roles authenticate locally and every unauthorized matrix case fails.

### 2. Tasks and proposals

Implement recurrence functions, task RPCs, proposal decisions, occurrence projection and Admin/Child/Parent task screens. Done when boundary and stale-proposal tests pass.

### 3. Completion, verification and approval

Implement submission limits, verification, approval/rejection, reward posting, audit/outbox and role screens. Done when concurrent/retried approval credits exactly once and unverified approval works.

### 4. Wallet, expenses and savings

Implement wallet projections, expenses/corrections, savings transfers/withdrawals and goals/archive requests. Done when concurrency tests prevent negative balances and all histories reconcile.

### 5. Payouts, adjustments and reporting

Implement payout/reversal, guarded adjustments, report functions and role views. Done when report definitions match effective ledger history.

### 6. Notifications and synchronization

Implement push-token lifecycle, outbox worker/retries/deep links, Realtime invalidation, focus/reconnect refresh and offline labels. Done when notification failure cannot affect commands and multi-device changes appear after signal/refetch.

### 7. Product hardening

Complete design tokens, accessibility, dense/empty/error states, performance, security review, E2E flows and physical-device verification.

### 8. Beta delivery

Provision staging, create signed preview APK, run gates, record build provenance and provide the private install link. Do not claim production readiness.

### 9. Public release preparation

Complete only after external legal/store/credential gates are provided. Produce signed AAB, closed-test evidence and release checklist; publication remains an explicit owner action/gate.

## Phase completion checklist

Before moving on:

- behavior matches locked specification;
- migrations apply fresh and from previous state;
- relevant unit/database/component/E2E tests pass;
- types, lint, format and Expo Doctor pass;
- security/authorization denial tests pass;
- docs reflect actual implementation;
- no unrelated dependency or lockfile churn;
- worktree is understood and intended changes are committed;
- PR contains reviewer-facing evidence.

## When to stop and ask

Ask only for missing external credentials/access, a direct conflict between locked documents, an unsafe/destructive action requiring owner authorization, or a verified third-party breaking change that invalidates the plan. For ordinary implementation details, follow the authority order and continue.
