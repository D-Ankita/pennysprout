# PennySprout API and Command Contracts

Status: **NORMATIVE IMPLEMENTATION CONTRACT**

The client uses Supabase reads protected by RLS and named transactional RPCs for every product mutation. Authentication provisioning/sign-in uses Edge Functions because it needs service credentials and server-side lockout. Authenticated clients receive no direct insert/update/delete grants on product tables. Client modules expose typed functions; screens do not call Supabase directly.

## 1. Common shapes

```ts
type CommandMeta = {
  idempotencyKey: string; // UUID v4, one logical attempt
};

type AppError = {
  code: ErrorCode;
  message: string;
  retryable: boolean;
  correlationId?: string;
  fieldErrors?: Record<string, string>;
};

type CommandResult<T> =
  | { ok: true; data: T; replayed: boolean }
  | { ok: false; error: AppError };
```

Money values are integer paise. IDs are UUIDs. Timestamps are ISO-8601 UTC strings. Local calendar dates are `YYYY-MM-DD`. Empty optional strings are normalized to `null`.

## 2. Stable error codes

`AUTH_INVALID_CREDENTIALS`, `AUTH_ACCOUNT_LOCKED`, `AUTH_PASSWORD_CHANGE_REQUIRED`, `MEMBERSHIP_DISABLED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_FAILED`, `STALE_PROPOSAL`, `TASK_INACTIVE`, `OCCURRENCE_NOT_AVAILABLE`, `COMPLETION_LIMIT_REACHED`, `SUBMISSION_ATTEMPT_LIMIT_REACHED`, `ALREADY_DECIDED`, `IDEMPOTENCY_CONFLICT`, `INSUFFICIENT_SPENDABLE`, `INSUFFICIENT_SAVINGS`, `PAYOUT_EXCEEDS_UNPAID`, `ALREADY_REVERSED`, `NETWORK_UNAVAILABLE`, `SERVER_UNAVAILABLE`, `UNKNOWN_ERROR`.

The UI maps expected codes to approved copy. Raw SQL messages, stack traces and secrets are never returned.

## 3. Authentication Edge Functions

### `auth-sign-in`

Input: `{ username, password }`. Normalize username, enforce lockout, look up the service-only random Auth alias, call Supabase password grant, update failure controls, and return the Supabase session plus `mustChangePassword`. Response is generic on all credential failures. The client must not render or log the Auth email that may be present in the session user object.

### `admin-create-member`

Admin JWT required. Input: `{ householdId, username, displayName, role, temporaryPassword, meta }`. Only `CHILD` or `PARENT` may be created after household bootstrap. Generates a cryptographically random Auth alias under the reserved internal domain, then creates Auth user, private login identity, profile and membership atomically/compensatably. Returns the member projection; never persists or re-returns the password after the response.

### `admin-reset-password`

Admin JWT required. Input: `{ householdId, userId, temporaryPassword, meta }`. Updates Auth password, sets forced-change flag, revokes sessions and audits the action.

### `change-temporary-password`

Authenticated user input: `{ newPassword }`. Updates Auth password, clears forced-change flag and revokes other sessions.

## 4. Database RPC catalogue

All mutation RPCs accept `p_idempotency_key uuid` except simple verification/cancellation where a unique database constraint already makes replay safe. All derive actor from `auth.uid()`; no caller-supplied actor is trusted.

| RPC | Authorized actor | Required result |
|---|---|---|
| `admin_create_task` | Admin | Full task projection |
| `admin_update_task` | Admin | Task with incremented version |
| `admin_set_task_status` | Admin | Updated task |
| `submit_task_proposal` | Child | Pending proposal |
| `cancel_task_proposal` | Requesting Child | Cancelled proposal |
| `decide_task_proposal` | Admin | Decision plus applied task |
| `submit_completion` | Child/Parent/Admin | Pending completion snapshot |
| `verify_completion` | Parent/Admin | Verification |
| `approve_completion` | Admin | Approved completion, transaction and balances |
| `reject_completion` | Admin | Rejected completion |
| `record_expense` | Child/Admin | Expense transaction and balances |
| `submit_expense_correction` | Child | Pending request |
| `cancel_expense_correction` | Requesting Child | Cancelled request |
| `decide_expense_correction` | Admin | Decision, reversal/replacement and balances |
| `deposit_to_savings` | Child/Admin | Transfer transaction and balances |
| `submit_savings_withdrawal` | Child | Pending request |
| `cancel_savings_withdrawal` | Requesting Child | Cancelled request |
| `decide_savings_withdrawal` | Admin | Decision, transaction and balances |
| `create_savings_goal` | Child/Admin | Goal |
| `update_savings_goal` | Owning Child/Admin | Goal |
| `submit_goal_archive` | Child | Pending archive request |
| `decide_goal_archive` | Admin | Decision and archived/unchanged goal |
| `record_payout` | Admin | Payout and balances |
| `reverse_payout` | Admin | Reversal and balances |
| `create_adjustment` | Admin | Adjustment and balances |
| `set_member_status` | Admin | Updated membership |
| `register_push_token` | Current user | Token registration projection |

Detailed SQL signatures use entity IDs, validated typed values, optional notes, and the idempotency key. Each function locks decision rows with `FOR UPDATE`; money commands take the `(household, child)` advisory lock before reading balances.

### Exact RPC signatures

Every function returns one `jsonb` `CommandResult` envelope. Defaultable parameters are still sent explicitly by the typed client so request hashing is stable.

```sql
admin_create_task(
  p_title text, p_description text, p_category task_category,
  p_reward_minor bigint, p_recurrence recurrence_type,
  p_anchor_date date, p_weekdays smallint[], p_completion_limit smallint,
  p_activate boolean, p_idempotency_key uuid
) returns jsonb

admin_update_task(
  p_task_id uuid, p_expected_version integer,
  p_title text, p_description text, p_category task_category,
  p_reward_minor bigint, p_recurrence recurrence_type,
  p_anchor_date date, p_weekdays smallint[], p_completion_limit smallint,
  p_idempotency_key uuid
) returns jsonb

admin_set_task_status(
  p_task_id uuid, p_expected_version integer, p_status task_status,
  p_reason text, p_idempotency_key uuid
) returns jsonb

submit_task_proposal(
  p_proposal_type proposal_type, p_task_id uuid, p_base_task_version integer,
  p_title text, p_description text, p_category task_category,
  p_reward_minor bigint, p_recurrence recurrence_type,
  p_anchor_date date, p_weekdays smallint[], p_completion_limit smallint,
  p_request_note text, p_idempotency_key uuid
) returns jsonb

cancel_task_proposal(p_proposal_id uuid) returns jsonb

decide_task_proposal(
  p_proposal_id uuid, p_decision review_status,
  p_applied_title text, p_applied_description text,
  p_applied_category task_category, p_applied_reward_minor bigint,
  p_applied_recurrence recurrence_type, p_applied_anchor_date date,
  p_applied_weekdays smallint[], p_applied_completion_limit smallint,
  p_review_note text, p_idempotency_key uuid
) returns jsonb

submit_completion(p_task_id uuid, p_child_user_id uuid, p_idempotency_key uuid) returns jsonb
verify_completion(p_completion_id uuid, p_note text) returns jsonb
approve_completion(p_completion_id uuid, p_reward_minor bigint, p_note text, p_idempotency_key uuid) returns jsonb
reject_completion(p_completion_id uuid, p_reason text, p_idempotency_key uuid) returns jsonb

record_expense(
  p_child_user_id uuid, p_amount_minor bigint, p_description text,
  p_category expense_category, p_need_want need_want, p_expense_date date,
  p_idempotency_key uuid
) returns jsonb

submit_expense_correction(
  p_expense_transaction_id uuid, p_type expense_correction_type,
  p_reason text, p_replacement_amount_minor bigint,
  p_replacement_description text, p_replacement_category expense_category,
  p_replacement_need_want need_want, p_replacement_expense_date date,
  p_idempotency_key uuid
) returns jsonb

cancel_expense_correction(p_request_id uuid) returns jsonb
decide_expense_correction(p_request_id uuid, p_decision review_status, p_review_note text, p_idempotency_key uuid) returns jsonb

deposit_to_savings(p_child_user_id uuid, p_amount_minor bigint, p_goal_id uuid, p_idempotency_key uuid) returns jsonb
submit_savings_withdrawal(p_amount_minor bigint, p_reason text, p_idempotency_key uuid) returns jsonb
cancel_savings_withdrawal(p_request_id uuid) returns jsonb
decide_savings_withdrawal(p_request_id uuid, p_decision review_status, p_review_note text, p_idempotency_key uuid) returns jsonb

create_savings_goal(p_name text, p_target_minor bigint, p_idempotency_key uuid) returns jsonb
update_savings_goal(p_goal_id uuid, p_name text, p_target_minor bigint, p_idempotency_key uuid) returns jsonb
submit_goal_archive(p_goal_id uuid, p_reason text, p_idempotency_key uuid) returns jsonb
decide_goal_archive(p_request_id uuid, p_decision review_status, p_review_note text, p_idempotency_key uuid) returns jsonb

record_payout(
  p_child_user_id uuid, p_amount_minor bigint, p_method payout_method,
  p_paid_at timestamptz, p_note text, p_external_reference text,
  p_idempotency_key uuid
) returns jsonb

reverse_payout(p_transaction_id uuid, p_reason text, p_idempotency_key uuid) returns jsonb
create_adjustment(p_child_user_id uuid, p_bucket ledger_bucket, p_signed_amount_minor bigint, p_reason text, p_related_transaction_id uuid, p_idempotency_key uuid) returns jsonb
set_member_status(p_user_id uuid, p_status membership_status, p_reason text, p_idempotency_key uuid) returns jsonb
register_push_token(p_expo_push_token text, p_device_label text, p_idempotency_key uuid) returns jsonb
```

Decision parameters accept only the relevant terminal value (`APPROVED` or `REJECTED`); cancellation has its own function. Nullable replacement/applied inputs are validated according to proposal/correction type. Admin actions always derive household membership from the target entity rather than accepting a household ID from the client.

Every migration that creates an RPC must immediately `REVOKE ALL` from `PUBLIC`, `anon`, and `authenticated`, then grant only the intended role. Authenticated product RPCs grant `EXECUTE` to `authenticated`; authentication/private-helper RPCs grant only to `service_role`. Every `SECURITY DEFINER` function sets `search_path = ''`, schema-qualifies objects, validates `auth.uid()`/membership explicitly, and is covered by direct unauthorized-invocation tests.

## 5. Read contracts

Use stable database views/functions rather than duplicating joins in screens:

- `my_session_context`: membership, role, household and forced-password-change state;
- `today_tasks`: task plus derived occurrence availability and submission state;
- `pending_approval_counts`: Admin badge counts;
- `completion_detail`: completion snapshot and verifications;
- `wallet_balances`: spendable, savings and unpaid earnings;
- `effective_expenses`: original/correction-aware expense projection;
- `report_summary`: period totals calculated server-side;
- `activity_feed`: cursor-paginated audit-safe history.

List pagination is cursor-based using `(created_at, id)`, defaults to 25 and caps at 100. Sort is deterministic, newest first except approval queues, which are oldest first.

## 6. Idempotency and retry

- The client creates one key when the user initiates a logical command and retains it across transport retries.
- Canonical request hashing excludes transient metadata and includes all behavior-changing input.
- Same actor/key/command/hash returns the stored completed result with `replayed: true`.
- Same key with different command/hash returns `IDEMPOTENCY_CONFLICT`.
- Network and 5xx failures may retry with exponential backoff up to two automatic retries for reads and zero automatic retries for non-idempotent authentication actions.
- Commands with keys may offer explicit user retry using the original key.

## 7. Realtime invalidation

Realtime payloads are signals only. Map table changes to query keys; never treat payloads as authoritative financial state. Refetch completion queues, task occurrence lists, wallet projections and activity after relevant signals. Always refetch on foreground and reconnection.
