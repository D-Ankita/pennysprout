# PennySprout Implementation Decision Closure

Status: **LOCKED FOR IMPLEMENTATION**

This file resolves product and engineering choices that an implementer might otherwise need to ask about. Claude Code must follow these decisions. A change requires an explicit owner decision and a corresponding update to this file and `DECISIONS.md`.

## 1. Product and platform

- PennySprout is a family habit and money-learning product, not a banking product.
- The first household is Gagan (Child), Mom and Dad (Parents), and Sister (Admin).
- The beta and initial family release are Android-only and distributed as a directly installed APK.
- There is no web, PWA, desktop, Windows, or macOS application.
- Code should avoid unnecessary Android-only domain assumptions, but iOS build and release work is out of scope.
- Android 9 and newer are supported.
- INR and `Asia/Kolkata` are fixed for the beta household.
- One active household per user is supported in the beta UX.
- The app never moves real money. It records rewards, spending, saving, and physical payouts performed outside the app.
- The approved scope must operate at zero monetary cost. No store publication, paid subscription, paid usage overage or payment method is permitted without a new owner decision.

## 2. Authentication and membership

- Users see only username and password authentication.
- Gagan, Mom, Dad, and Sister each receive separate credentials.
- No real email, phone number, OTP, magic link, or social login is required.
- Usernames are trimmed, lower-cased for comparison, limited to `a-z`, `0-9`, `_`, `.`, 3–30 characters, and globally unique.
- Supabase Auth uses a random, unguessable internal synthetic email generated at account creation. It is not derived from the username and is never intentionally displayed or logged. It may exist in internal Supabase session claims and is not treated as a secret or recovery channel.
- Sign-in goes through a trusted authentication gateway so server-side failure counting and lockout can be enforced. The unguessable Auth alias prevents practical bypass through Supabase's direct password endpoint.
- Five consecutive invalid attempts lock the username for 15 minutes. Successful authentication clears the counter.
- Login errors are always generic.
- Admin creates accounts with temporary passwords.
- Passwords require at least eight characters, one letter, and one number.
- First login requires a password change before product navigation.
- Admin may issue a new temporary password; users cannot use email recovery.
- A user may remain signed in on multiple devices.
- Changing a password revokes other sessions but preserves the current successful session.
- Disabled membership immediately blocks product access.
- Sessions are stored with `expo-secure-store`. The app requires sign-in again after 30 days without use. This is enforced without Supabase's paid session-timeout feature:
  - the client stores last activity in `expo-secure-store` and signs out immediately once 30 inactive days have elapsed;
  - the server keeps a private app-session record keyed to the Supabase Auth `session_id`, created by the authentication gateway and refreshed by the `touch_app_session` RPC;
  - every household authorization check requires an unrevoked app session used within the last 30 days, so an expired session is rejected lazily on its next request and the client signs out;
  - no nightly cleanup job or paid Supabase setting is required.

## 3. Task definitions and recurrence

- Task categories are `HOUSEHOLD`, `STUDY`, `HEALTH`, `RESPONSIBILITY`, `KINDNESS`, and `OTHER`.
- Recurrence types are `ONE_TIME`, `DAILY`, `SELECTED_WEEKDAYS`, and `WEEKLY`.
- Calendar calculations use household local time.
- A local day is `00:00:00` through the instant before the next local midnight.
- A week is Monday through Sunday. Weekly tasks reset Monday at local midnight.
- Selected-weekday tasks exist only on selected ISO weekdays.
- The beta recurrence interval is always one; “every N weeks” is not exposed.
- One-time tasks automatically become inactive after their first approved completion.
- Completion limit defaults to one and may be configured from one through five per occurrence.
- Recurrence changes apply only to future occurrence calculation. Historical completion snapshots never change.
- Inactive tasks reject new completions and remain in history.
- Photo, video, location, and file proof are out of scope.

## 4. Completion and approval

- Child, Parent, or Admin may mark a task complete for the household Child.
- Completion time is server time. Users cannot backdate or future-date completion.
- Parent verification is optional, informational, and never financial.
- Each Parent or Admin may verify a pending completion once.
- Admin may approve without verification.
- Admin may approve a completion they submitted; both actions remain visible in audit history.
- An approved reward may be any whole paise amount from ₹0 through ₹10,000.
- A review reason is mandatory when approved reward differs from the task snapshot reward.
- Rejection always requires a reason and creates no money.
- A rejected submission is terminal. A new submission may be made while the occurrence is still available.
- Rejected submissions do not consume the configured completion limit. At most three rejected attempts are accepted per task/Child/occurrence, so the absolute submission cap is `completion_limit + 3` (maximum eight).
- Approval and financial posting are one transaction.
- Approved and rejected completions are never reopened, edited, or deleted.

## 5. Task proposals

- Child may propose `CREATE`, `UPDATE`, or `DEACTIVATE`.
- Admin may approve as submitted, edit and approve, or reject.
- The proposal snapshot and the final applied values are both retained.
- Update/deactivation approval fails as stale if the task version changed after submission.
- Admin must review the current task and create/apply a replacement decision; the system never silently merges.
- Rejection requires a reason.

## 6. Expenses

- Categories are `FOOD`, `SCHOOL`, `TRANSPORT`, `ENTERTAINMENT`, `GIFTS`, `PERSONAL`, and `OTHER`.
- `NEED` or `WANT`, amount, description, category, and expense date are mandatory.
- Expense date may be today or up to 30 local calendar days earlier. Future dates are rejected.
- Child or Admin may record an expense; Parent may not.
- Expense cannot make spendable balance negative.
- Posted expenses are immutable.
- Child may request `VOID` or `REPLACE`; Admin approves or rejects with a mandatory reason.
- Approval appends a reversal and optional replacement in one transaction.

## 7. Savings and goals

- Child or Admin may transfer at least ₹1 from spendable to savings immediately.
- A deposit cannot make spendable negative.
- Child requests a savings withdrawal; Admin approves or rejects it.
- Admin cannot edit the requested amount. A different amount requires rejection and a new request.
- Approval rechecks savings under the financial lock.
- Savings goals do not own money. Allocations are reporting labels bounded by current savings.
- Child may create or edit a goal.
- Goal archival requires an Admin-approved request.
- Goal deletion is not supported.

## 8. Payouts and adjustments

- Only Admin records cash/UPI/other physical payouts.
- Payout cannot exceed unpaid earnings.
- Payout changes only unpaid earnings, not spendable or savings.
- Incorrect payouts use a linked reversal.
- Adjustments are exceptional, Admin-only, require a reason and preview, and appear in reports.
- Adjustments cannot make spendable or savings negative.
- Parent never creates a financial transaction, correction, payout, adjustment, or transfer.

## 9. Notifications and synchronization

- Beta notifications are transactional only.
- Admin receives new completion, task proposal, savings-withdrawal, goal-archive, and expense-correction notifications.
- Child receives every decision result.
- Parents receive no push notifications in beta.
- Daily reminders, promotional messaging, and quiet-hour settings are out of scope.
- Notification delivery is deduplicated and asynchronous; failure never rolls back the action.
- Supabase is the source of truth. Realtime invalidates cached queries; focus, reconnect, and pull-to-refresh recover missed events.
- Offline access is cached and read-only with a visible last-refresh time.
- There is no offline mutation queue.
- Financial results are never displayed optimistically.
- Client crashes are reported only through the restricted, append-only `report_client_error` RPC in the family Supabase project. Reports hold a sanitized error code, app version/build, environment, platform, route template, timestamps and server-derived user/household identifiers. Secrets, credentials, request bodies, financial values, usernames, free-form input and raw logs are never stored. Stack traces are allow-list sanitized and size-limited or omitted. Reporting is rate-limited per user and device, retained for 30 days, and its failure never affects product behavior. No paid crash-reporting or analytics service is used.

## 10. Streaks and reports

- Streaks are display-only in beta. Monetary streak bonuses are disabled and not implemented in the beta UI.
- Default report period is the current calendar month.
- Other periods are previous month, last three months, and inclusive custom local dates.
- Earnings group by approval date; expenses group by expense date.
- Reversed expenses are excluded from effective Need/Want totals.
- Completion rate is approved occurrences divided by available scheduled occurrences; pending and rejected are shown separately.
- Admin additionally sees unpaid earnings and payout history.
- PDF and CSV export are out of scope.

## 11. Explicitly deferred

The implementer must not add these during the approved scope:

- iOS release work;
- web or desktop clients;
- bank, UPI, gateway, or investment integration;
- automated streak bonuses;
- recurring allowance;
- photo proof;
- multiple active households in the UI;
- dark theme;
- report export;
- advertising or behavioral analytics;
- daily task reminders.
