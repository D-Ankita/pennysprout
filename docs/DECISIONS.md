# PennySprout Product and Architecture Decisions

This file records decisions that should not be silently changed during implementation.

## D-001: Product name

Working name: **PennySprout**

Tagline: **Small habits. Smart money.**

Trademark clearance remains pending official verification before public release.

## D-002: First beta roles

The first household has:
- one CHILD: Gagan
- two PARENT users: Mom and Dad
- one ADMIN: Sister

Architecture must not hard-code the names or assume exactly four records.

## D-003: Parent verification is optional

A completion does not require Parent verification before Admin approval.

Flow:

**Completed -> optional verification -> Admin approval -> earning credited**

Reason: requiring two approvals for every small daily task would add unnecessary friction.

## D-004: Admin is the financial gatekeeper

Parents may mark and verify completion but cannot generate wallet transactions.

Only Admin may:
- approve completion rewards
- record payouts
- create financial corrections
- approve withdrawals requiring approval

## D-005: Use a ledger, not mutable balances

Wallet amounts are calculated from immutable financial entries.

Reason:
- auditability
- easier debugging
- prevents hidden money changes
- supports future reporting

## D-006: Payout and earning are separate concepts

Approving a task creates an earning.

Recording cash or UPI given to the child creates a payout record.

Payout does not create a second earning.

The app should expose an **unpaid earnings** figure for Admin.

## D-007: No real-money movement in MVP

The app records what happened outside the app but does not send money.

No bank account, payment gateway or UPI integration is required for beta.

## D-008: Financial values use integer minor units

INR ₹5.00 is stored as 500 paise.

Never use floating-point arithmetic for money.

## D-009: Production-oriented stack

Working technical direction:
- React Native
- Expo
- TypeScript
- Supabase Auth
- PostgreSQL
- Supabase Row Level Security
- Expo notifications

Changes to this stack should be made deliberately and documented here.

## D-010: Beta-first, multi-household-ready

UX is optimized first for Gagan's household, but database keys and authorization boundaries must support independent households from day one.
