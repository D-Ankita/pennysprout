# PennySprout User Flows and Screen Contract

Status: **LOCKED FOR IMPLEMENTATION**

## 1. Information architecture

### Child navigation

Bottom tabs: `Today`, `Wallet`, `Savings`, `History`, `Profile`.

### Parent navigation

Bottom tabs: `Today`, `Completions`, `Reports`, `Profile`.

### Admin navigation

Bottom tabs: `Dashboard`, `Approvals`, `Tasks`, `Money`, `More`.

`More` contains Reports, Members, Notification Activity, Settings, and Profile. Do not squeeze more than five destinations into bottom navigation.

## 2. Universal screen states

Every server-backed screen implements:

- first load with a labelled activity indicator;
- refreshing without hiding usable content;
- purposeful empty state and valid next action;
- populated state using realistic/dense data;
- retryable error;
- offline cached state with last-refreshed time;
- permission denied;
- disabled membership redirect;
- submission progress with duplicate taps disabled;
- server-confirmed success;
- idempotent replay result.

Financial screens never infer success from a local state update.

## 3. Authentication flow

1. Sign-in asks for username and password only.
2. Inputs are trimmed as appropriate; username comparison is case-insensitive.
3. Submit remains disabled while in flight.
4. Every invalid/locked/unknown username response displays: “Username or password is incorrect. Try again or ask your Admin for help.”
5. A temporary-password session opens only the forced password-change screen.
6. Successful password change revokes other sessions and enters the role home.
7. Disabled membership signs out and displays an Admin-contact message.

Admin member management supports create account, copy/display one-time temporary credentials, disable, enable, reset password, and view audit history. The temporary password is shown only in the successful command response and is never stored in application tables or logs.

## 4. Child flows

### Today

Order: overdue is not used; show available unfinished tasks, submitted/pending completions, then completed today. Each task shows title, category, reward, recurrence label and remaining completions. Primary action is `Mark complete`.

Marking complete uses a confirmation sheet with task, reward snapshot and statement that Admin approval is required. Success moves the item to Pending Approval.

Task detail shows description, recurrence, limit, reward, current occurrence status and history. `Suggest a change` opens a complete proposal form.

### Wallet

Show three separately labelled values: Spendable, Savings, and Earnings not yet paid. Never combine them into “total wallet.” Then show recent earnings/expenses and actions `Add expense` and `Move to savings`.

Expense form requires amount, description, category, Need/Want and date. History opens an immutable transaction detail with `Request correction` when eligible.

### Savings

Show savings balance, active goals and transfer history. Actions are `Move money to savings`, `Request withdrawal`, and `Create goal`. Goal detail shows target, informational allocation and history. Archival creates an Admin request.

### History

Filter by Tasks, Money and Decisions. Default newest first; server pagination is cursor-based.

## 5. Parent flows

Today shows scheduled tasks and their state, with `Mark complete` where available. Completions shows pending items first and history second. A pending completion may be verified once with an optional note. The screen explicitly states that verification does not credit money and Admin still decides.

Reports are read-only. Parents never see a control that initiates financial mutation or task changes.

## 6. Admin flows

### Dashboard and approvals

Dashboard begins with four actionable counts: completions, task proposals, savings/goal requests, and expense corrections. Oldest pending item appears first. Secondary content is unpaid earnings, recent decisions and task status.

Approval detail always shows actor, timestamps, relevant snapshots, verification evidence and history. Approve and Reject are distinct actions. Reject requires a reason. Completion approval requires a reason when reward differs from default and previews resulting balances.

### Tasks

List filters: Active, Draft, Inactive. Task form includes title, description, category, reward, recurrence, weekdays where relevant and completion limit. Deactivation requires confirmation. Historical references remain accessible.

### Money

Child financial summary, payout history and adjustment history share one area. Recording payout requires amount, method, paid time and confirmation. Adjustment requires bucket, signed amount, reason, resulting-balance preview and a second confirmation.

### Members

Admin can create, disable/enable and reset members but cannot delete their history or demote the only active Admin. Role changes are out of beta scope after account creation; correcting a wrong role requires disabling and recreating before the account has history, otherwise a documented migration.

## 7. Reporting definitions

Periods are current month, previous month, last three months, or inclusive custom local dates. Earnings use approval date; expenses use expense date; payouts use paid time. Reversals affect effective totals but remain visible in history. Completion rate is approved scheduled occurrences divided by available scheduled occurrences. Pending and rejected counts are separate.

## 8. Visual and accessibility direction

- Tone: encouraging, calm and trustworthy; child-friendly without cartoonish finance metaphors.
- Use the exact color, typography, spacing and component tokens in `UI_DESIGN_SYSTEM.md`.
- No gradients, glass panels, decorative metric cards, emoji icons or excessive pills.
- Use real icons and text labels for non-obvious actions.
- Minimum touch target is 44×44 points.
- Support system text scaling without clipped actions.
- Color is never the only status signal.
- Every input has a persistent label; errors are adjacent and announced.
- Destructive/financial actions require confirmation and describe the effect.
- Light theme ships first; dark theme is not implemented.
- Format money using Indian grouping and two decimals where detail matters.
- Display dates as `28 Sep 2026`; include time only where operationally useful.
