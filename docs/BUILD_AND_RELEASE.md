# PennySprout Build, Distribution and Release

Status: **LOCKED DELIVERY PLAN**

## 1. Environments

| Environment | Backend | Build | Data |
|---|---|---|---|
| Local | Supabase CLI on Podman Desktop | local development build | deterministic seed/test data |
| Family | One Supabase Free project | locally signed release APK | real household |

URLs, publishable keys, Auth users, push tokens and secrets never cross environments. Settings shows environment and version. Family configuration cannot fall back to local.

## 2. Build profiles

- `development`: local Expo development build against local Supabase.
- `family`: locally built and signed release APK against the hosted Supabase Free project.

Family distribution is direct APK sideloading. EAS Build, EAS Submit, Google Play Console, AAB publication and paid distribution services are not required or approved. An optional EAS Free-plan build may be used only when its free quota is available and no billing method or overage is enabled.

## 3. Signing and ownership

- Generate the Android keystore locally with the Android/JDK toolchain.
- Securely back up the keystore, alias and passwords in two owner-controlled locations outside Git.
- Service accounts, keystores and credentials are never committed, logged or embedded in documentation.
- Loss of signing access blocks release and is escalated immediately.

## 4. Versioning and updates

- Begin at app version `0.1.0`.
- Increment Android `versionCode` for every distributed binary.
- Include version, build number, environment and Git SHA in diagnostics.
- Tag family releases `vX.Y.Z` after the distributed commit is verified.
- Over-the-air updates are not required; distribute a new signed APK for every release.

## 5. Migration rollout

1. Add a new immutable migration.
2. Prove fresh reset and upgrade from prior schema.
3. Pass constraints, RLS, function and concurrency tests.
4. Apply locally and run smoke/E2E tests.
5. Confirm the encrypted hosted-project export.
6. Apply the hosted family migration.
7. Verify migration version, reconciliation and critical flows.
8. Forward-repair with a new migration if rollback risks data loss.

Never edit a migration already applied to the hosted family project. Hosted migrations connect through the shared session-mode pooler; the paid IPv4 add-on is prohibited.

## 6. Backup and recovery

- Do not require Supabase paid managed backups or PITR.
- Create an encrypted logical export before every hosted migration and at least daily while the beta is actively used, connecting through the shared session-mode pooler (see `ZERO_COST_OPERATIONS.md`).
- Retain the latest seven successful exports in two owner-controlled locations outside Git.
- Beta targets: recovery point within 24 hours and service restoration within 8 hours.
- Prove a restore before family beta and after any backup-script change.
- Maintain a reconciliation query for completion rewards, postings and projected balances.
- Notifications can be regenerated; financial history cannot.

## 7. Beta release gate

All must be verified:

- intended Git branch is clean, reviewed and synchronized;
- CI passes from clean checkout;
- local migration and RLS tests pass;
- the hosted Free project is within all quotas and has no paid plan/add-on;
- signed family APK installs and upgrades;
- core workflows pass on a physical device;
- notifications work on a physical device;
- ledger reconciliation returns no mismatch;
- Admin can create, disable and recover accounts;
- no critical/high security issue remains;
- known limitations and build provenance are recorded.

## 8. Paid/public distribution boundary

Public-store release is outside the approved zero-cost scope. It requires a separate owner decision and a fresh cost/legal review before any Play Console account, AAB, store listing, custom domain or paid service is introduced.

Local checks or a generated APK do not mean the family release is installed and verified.
