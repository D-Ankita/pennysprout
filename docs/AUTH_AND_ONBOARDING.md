# PennySprout Authentication and Onboarding

Status: **NORMATIVE SECURITY FLOW**

## 1. Identity model

- Product identity is a globally unique normalized username.
- Supabase Auth identity is a cryptographically random alias such as `<32 random hex>@login.pennysprout.invalid`.
- Alias and username mapping lives only in `private.login_identities`.
- The alias is not derived from username and is not an email/recovery channel.
- Product code never displays or logs it, although Supabase may include it in internal session/user claims.

## 2. First Admin bootstrap

There is no public “create household” endpoint in beta.

Implement `scripts/bootstrap-admin.ts` for one-time owner execution against the local stack or the hosted family project:

1. Require an explicit environment selector and confirmation of the resolved Supabase URL.
2. Read service-role key from environment; never accept/print it as an argument.
3. Prompt interactively for household name, Admin username/display name and temporary password; password input is hidden.
4. Generate the random Auth alias.
5. Create Auth user with email confirmed, then insert profile, household, active Admin membership, login identity/control and audit event.
6. On database failure, delete the newly created Auth user; report a safe correlation ID if compensation fails.
7. Be idempotent by normalized username/household: refuse a conflicting rerun and never reset credentials implicitly.

The deterministic local seed may create all four beta identities using documented local-only passwords. Family-project passwords never appear in seed files.

## 3. Admin member creation

The `admin-create-member` Edge Function verifies JWT, active Admin membership and household ownership. It accepts only Child/Parent roles after bootstrap. It validates username/password, confirms uniqueness, creates Auth user, then calls a service-only database function to insert identity/profile/membership/audit. On failure it compensates by deleting the Auth user.

Return temporary credentials only in the successful response for immediate copy/share. Do not persist plaintext password or include it in analytics, logs, errors or audit data.

## 4. Sign-in and lockout

`auth-sign-in` is the only product sign-in path:

1. Normalize username.
2. Return generic failure for missing identity, locked control or invalid password.
3. If locked and time remains, do not call GoTrue.
4. Call password grant using private alias.
5. On failure, atomically increment count; fifth failure sets `locked_until = now() + 15 minutes`.
6. On success, clear count/lock, verify active membership, read `session_id` from the new access token and call the service-only `gateway_start_app_session(user_id, session_id)`. If that call fails, sign the new session out and return a generic failure. Return session plus forced-change state.
7. Rate-limit by normalized username and coarse client/IP signal at the function/platform layer without storing raw IP long-term.

Because Auth aliases are unguessable, direct GoTrue password calls cannot practically target a known username and bypass product lockout.

## 5. App sessions and 30-day inactivity

Supabase's session time-box and inactivity timeout are paid features and are not used.

- `private.app_sessions` stores `session_id` (the Supabase Auth JWT claim), user, `last_activity_at` and revocation reason. Clients have no table access.
- The sign-in gateway creates the record. The app calls `touch_app_session` on launch and every return to the foreground; it refreshes `last_activity_at` or returns `AUTH_SESSION_EXPIRED`/`MEMBERSHIP_DISABLED`.
- `is_active_household_member` and `has_household_role` require an unrevoked app session used within 30 days, so RLS and every RPC reject an expired session lazily on its next request. `touch_app_session` also records the `INACTIVITY` revocation. No scheduled cleanup is required; sessions ended more than 90 days ago are deleted in bounded batches at later sign-ins.
- On `AUTH_SESSION_EXPIRED`, the client signs out. Independently, the client keeps last activity in `expo-secure-store` and signs out immediately once 30 inactive days have elapsed.
- Sign-out calls `end_app_session` before Supabase sign-out.
- Password change revokes all other app sessions (`PASSWORD_CHANGED`); Admin reset revokes all (`ADMIN_RESET`); membership disablement revokes all (`MEMBERSHIP_DISABLED`) through `gateway_revoke_app_sessions` or the same private helper.

## 6. Temporary password and recovery

- `must_change_password` blocks all product routes except password change and sign-out.
- Password change calls Supabase Auth update, clears the flag through a trusted function and revokes other Auth and app sessions.
- Admin reset generates/accepts a new compliant temporary password, updates Auth, sets the flag, revokes all Auth and app sessions and audits actor/target/reason without the password.
- No email/phone recovery exists in beta.

## 7. Membership disablement

Disablement is an Admin command requiring a reason. It sets membership `DISABLED`, records timestamp/audit, revokes target Auth and app sessions and disables active push tokens. Every RPC checks active membership; cached/offline screens sign out on next refresh and show the Admin-contact message.

The sole active Admin cannot disable themselves. Role changes are not supported after an account has history.

## 8. Tests

Test username normalization/collisions, random-alias non-derivation, generic failures, fifth-attempt lock, expiry, concurrent failed attempts, successful reset, forced change, session revocation, app-session creation at sign-in, 29-day acceptance and 30-day lazy rejection, client secure-store inactivity sign-out, session-id mismatch denial, sign-out ending the app session, disabled member denial, cross-household Admin attempts, compensation after partial creation and absence of credentials in logs/audit.
