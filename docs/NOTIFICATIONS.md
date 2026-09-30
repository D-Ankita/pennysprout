# PennySprout Notification Delivery

Status: **NORMATIVE BETA DELIVERY CONTRACT**

## 1. Architecture

Transactional RPCs insert deduplicated rows into `notification_outbox` in the same database transaction as the business change. A Supabase Edge Function named `process-notification-outbox` is invoked every minute by Supabase Cron. It claims due rows using `FOR UPDATE SKIP LOCKED`, sends through Expo Push Service, and records ticket/receipt outcomes.

Push delivery is never part of command success and never changes financial state.

## 2. Events and recipients

| Event | Recipient |
|---|---|
| Completion submitted | All active Admin members |
| Task proposal submitted | All active Admin members |
| Expense correction submitted | All active Admin members |
| Savings withdrawal submitted | All active Admin members |
| Goal archive submitted | All active Admin members |
| Any request approved/rejected | Requesting Child |
| Completion approved/rejected | Target Child |

Parents receive no beta pushes. Do not send daily reminders or promotional messages.

## 3. Payload and deep links

Notification contains a short non-sensitive title/body and data `{ eventType, entityType, entityId }`. It never includes balances, passwords, usernames, rejection details or free-form financial notes. On open, the app authenticates, navigates to the authorized detail route and refetches current state; payload data is not trusted as current content.

## 4. Deduplication and retries

- Deduplication key: `<event-type>:<entity-id>:<recipient-user-id>:<decision-version>`.
- One outbox row fans out to each recipient separately.
- Claim batches of at most 100.
- Claim timeout is 10 minutes; stale `PROCESSING` rows become retryable.
- Retry transient failures after 1, 5, 15, 60 and 360 minutes, maximum five attempts.
- Permanent invalid-token response disables that token and completes the row without retrying that token.
- After five transient failures mark `FAILED`; Admin Notification Activity shows a generic failure and supports a trusted manual retry that increments an audit event.
- Store provider ticket/receipt IDs, not entire provider responses.

## 5. Token lifecycle

Register token through `register_push_token`, owned by current user. Upsert by token, update last seen/device label and reactivate when valid. Disable on logout from that device, membership disablement, explicit permission removal or permanent Expo invalid-token receipt. Authenticated clients cannot read raw tokens from tables.

## 6. Permissions and UX

Request notification permission after sign-in with contextual copy, not on first launch. Denial does not block app use. Settings shows Enabled/Disabled and an OS-settings link. In-app approval queues and refetch remain the reliability path.

## 7. Verification

Test transactional enqueue, deduplication, concurrent workers, stale claims, retry schedule, invalid-token disablement, safe payloads, unauthorized deep links, notification failure isolation and receipt processing on a physical Android device or an Android emulator image that includes Google Play services (required for FCM; no Play Console account is involved).
