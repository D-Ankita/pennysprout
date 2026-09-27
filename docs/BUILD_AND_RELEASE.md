# PennySprout Build, Distribution and Release

Status: **LOCKED DELIVERY PLAN**

## 1. Environments

| Environment | Backend | Build | Data |
|---|---|---|---|
| Local | Supabase CLI | development client | deterministic seed |
| Staging | Separate hosted Supabase | preview APK | beta/test only |
| Production | Separate hosted Supabase | production AAB | real household |

URLs, publishable keys, Auth users, push tokens, secrets and EAS variables never cross environments. Settings shows environment and version. Production configuration cannot fall back to staging/local.

## 2. Build profiles

- `development`: Expo development client; development environment.
- `preview`: signed internal-distribution APK; staging environment.
- `production`: signed Android App Bundle; production environment.

Family beta distribution uses the private EAS build link/QR for the preview APK. Google Play submission uses the AAB. APK and AAB are different artifacts; an AAB is not sent directly to family devices.

## 3. Signing and ownership

- EAS may generate/manage the initial Android keystore under the owner’s Expo account.
- Export and securely back up the keystore, alias and passwords outside Git.
- Enable Google Play App Signing before public release.
- Service accounts, keystores and credentials are never committed, logged or embedded in documentation.
- Loss of signing access blocks release and is escalated immediately.

## 4. Versioning and updates

- Begin at app version `0.1.0`.
- Increment Android `versionCode` for every uploaded binary.
- Include version, build number, environment and Git SHA in diagnostics.
- Tag production releases `vX.Y.Z` after the published commit is verified.
- EAS Update is permitted only for JavaScript/assets compatible with the installed runtime version.
- Native dependencies, permissions, plugins or configuration require a new APK/AAB.

## 5. Migration rollout

1. Add a new immutable migration.
2. Prove fresh reset and upgrade from prior schema.
3. Pass constraints, RLS, function and concurrency tests.
4. Apply to staging and run smoke/E2E tests.
5. Confirm production backup.
6. Apply production migration.
7. Verify migration version, reconciliation and critical flows.
8. Forward-repair with a new migration if rollback risks data loss.

Never edit a migration already applied to production.

## 6. Backup and recovery

- Enable Supabase-managed production backups before production use.
- Take/confirm a backup before risky migrations.
- Beta targets: recovery point within 24 hours and service restoration within 8 hours.
- Run quarterly restore exercises after public release.
- Maintain a reconciliation query for completion rewards, postings and projected balances.
- Notifications can be regenerated; financial history cannot.

## 7. Beta release gate

All must be verified:

- intended Git branch is clean, reviewed and synchronized;
- CI passes from clean checkout;
- staging migration and RLS tests pass;
- signed preview APK installs and upgrades;
- core workflows pass on a physical device;
- notifications work on a physical device;
- ledger reconciliation returns no mismatch;
- Admin can create, disable and recover accounts;
- no critical/high security issue remains;
- known limitations and build provenance are recorded.

## 8. Public release gate

Additionally require trademark decision, privacy policy, terms, support page/email, child-data/legal review, account deletion, production backup/restore evidence, privacy-disclosed crash reporting, Play Console Data Safety form, listing assets, closed-testing completion, signed AAB, store approval and post-release production smoke tests.

Local checks, a generated AAB, or a successful upload do not individually mean the app is live.
