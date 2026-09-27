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

## D-011: A task completion belongs to one occurrence

Recurring tasks generate deterministic occurrence keys in the household timezone. A completion stores the occurrence key that was valid when it was submitted. The database enforces the configured per-occurrence limit.

Reason: timestamps alone are not a reliable duplicate boundary, especially around midnight, retries, or later recurrence edits.

## D-012: Financial history uses transactions and postings

The financial source of truth is an immutable transaction header with one or more immutable postings to named balance buckets:

- `SPENDABLE`
- `SAVINGS`
- `UNPAID_EARNINGS`

Reason: a single event can affect more than one meaningfully different balance. For example, an earning increases both the child's virtual spendable amount and the Admin's unpaid settlement figure, while a payout changes only unpaid settlement.

## D-013: Approved actions use server-side database functions

Completion approval, payout recording, savings transfers, savings-withdrawal decisions, expense correction decisions, and task-proposal decisions execute through transactional PostgreSQL functions. Clients cannot write ledger tables directly.

Reason: role checks, state transitions, audit records, and financial postings must commit or fail together.

## D-014: Financial corrections never rewrite posted history

Posted expenses and other financial transactions are never edited or deleted. An approved correction reverses the original transaction and, when appropriate, posts a replacement transaction linked to it.

Reason: the family must be able to reconstruct what was originally recorded and why it changed.

## D-015: Savings withdrawals require Admin approval

A Child may move available spendable money into savings immediately. Returning savings to spendable requires a pending request and Admin approval.

Reason: saving should be easy, while taking money back out is an intentional review moment.

## D-016: Non-negative balances are enforced at write time

Expense posting, saving, and approved savings withdrawal lock the child's financial scope and reject any operation that would make the affected virtual balance negative.

Reason: a read-then-write check in the client is vulnerable to concurrent requests.

## D-017: Historical facts use snapshots

Completions snapshot the task title, default reward, and recurrence occurrence. Ledger descriptions and transaction metadata snapshot the facts needed to explain a posting later.

Reason: changing a task must not rewrite the meaning of old completions or earnings.

## D-018: One active household membership per user in beta

The schema is household-keyed and supports future multi-household membership, but beta authorization and navigation assume one active household membership per authenticated user. Multi-household switching is deferred until its UX and authorization tests are implemented.

## D-019: Notifications use a transactional outbox

Trusted commands enqueue a deduplicated notification in the same database transaction as the state change. A separate worker sends Expo notifications with retry and failure tracking.

Reason: an Expo outage must not roll back an approval, and a database commit must not lose its corresponding notification intent.

## D-020: Recurrence is evaluated in household time

Occurrence dates and weekly boundaries use the household's IANA timezone. UTC is retained for event timestamps, while the derived local occurrence date is stored on each completion.

Reason: family expectations follow local calendar days, and historical occurrence membership must not move when viewed from another device timezone.
