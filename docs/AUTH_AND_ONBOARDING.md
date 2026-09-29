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

Implement `scripts/bootstrap-admin.ts` for one-time owner execution against local, staging or production:

1. Require an explicit environment selector and confirmation of the resolved Supabase URL.
2. Read service-role key from environment; never accept/print it as an argument.
3. Prompt interactively for household name, Admin username/display name and temporary password; password input is hidden.
4. Generate the random Auth alias.
5. Create Auth user with email confirmed, then insert profile, household, active Admin membership, login identity/control and audit event.
6. On database failure, delete the newly created Auth user; report a safe correlation ID if compensation fails.
7. Be idempotent by normalized username/household: refuse a conflicting rerun and never reset credentials implicitly.

The deterministic local seed may create all four beta identities using documented non-production passwords. Staging/production passwords never appear in seed files.

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
6. On success, clear count/lock, verify active membership and return session plus forced-change state.
7. Rate-limit by normalized username and coarse client/IP signal at the function/platform layer without storing raw IP long-term.

Because Auth aliases are unguessable, direct GoTrue password calls cannot practically target a known username and bypass product lockout.

## 5. Temporary password and recovery

- `must_change_password` blocks all product routes except password change and sign-out.
- Password change calls Supabase Auth update, clears the flag through a trusted function and revokes other sessions.
- Admin reset generates/accepts a new compliant temporary password, updates Auth, sets the flag, revokes all sessions and audits actor/target/reason without the password.
- No email/phone recovery exists in beta.

## 6. Membership disablement

Disablement is an Admin command requiring a reason. It sets membership `DISABLED`, records timestamp/audit, revokes target sessions and disables active push tokens. Every RPC checks active membership; cached/offline screens sign out on next refresh and show the Admin-contact message.

The sole active Admin cannot disable themselves. Role changes are not supported after an account has history.

## 7. Tests

Test username normalization/collisions, random-alias non-derivation, generic failures, fifth-attempt lock, expiry, concurrent failed attempts, successful reset, forced change, session revocation, disabled member denial, cross-household Admin attempts, compensation after partial creation and absence of credentials in logs/audit.
