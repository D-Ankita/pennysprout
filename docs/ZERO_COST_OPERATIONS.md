# PennySprout Zero-Cost Operations

Status: **LOCKED COST CONSTRAINT**

PennySprout must be developable, tested, hosted for the family beta, built and distributed without purchasing a subscription, store account, domain or usage overage. No payment method may be attached merely to prevent a quota stop. If a free quota is exhausted, work pauses or falls back to local tooling; it never upgrades automatically.

## Approved zero-cost services

| Capability | Locked choice | Cost guardrail |
|---|---|---|
| Local containers | Podman Desktop | Free/open-source Docker-compatible runtime; Docker Desktop is not required |
| Local backend | Supabase CLI on Podman | Runs only on the developer machine and local network |
| Family backend | One Supabase Free project | No paid organization, add-on, custom domain, PITR or usage overage |
| Android builds | Local Android SDK/Gradle through Expo prebuild/run commands | EAS Build is optional and must remain on its non-billable Free plan; local builds are the default |
| Distribution | Directly sideload a signed APK | No Google Play Console, App Store or paid distribution service |
| Push transport | Expo Push Service plus Firebase Cloud Messaging Spark plan | Both are used only in their no-cost modes; no Blaze billing account |
| CI | Included GitHub Actions allowance plus mandatory local checks | If included minutes are exhausted, CI waits; no paid minutes or larger runners |
| Monitoring | Application logs and provider free dashboards | No paid monitoring, analytics, log drain or retention add-on |
| Backups | Encrypted logical database exports owned by Admin | No Supabase paid backup/PITR feature |
| Web presence | None | No custom domain, hosting, support site or paid email service |

## Supabase Free constraints

- Use one hosted project for the family beta; local Podman is the development and test environment.
- Stay below the Free plan quotas. Add a quota review to every release checklist.
- Free projects may pause after inactivity and have no production SLA. The family accepts a cold start or temporary unavailability.
- Do not enable a Pro plan, paid compute, custom domain, PITR, log drain or other paid add-on.
- Before every hosted migration and at least daily while the beta is actively used, create an encrypted logical export and retain the latest seven successful exports in two owner-controlled locations outside Git. Test restoration before beta and after any backup-script change.
- This application records virtual family balances, not bank-held money. If the reliability needs later exceed these constraints, stop and obtain a new owner decision; do not silently introduce cost.

## Build and signing constraints

- Generate and retain the Android signing keystore locally. Never depend on a paid account to recover it.
- Produce a signed release APK locally and share it directly with the four family users.
- Every update must use the same signing key and a higher Android `versionCode`.
- Do not produce a Play Store release, AAB submission or paid EAS build within the approved scope.

## Cost review gate

Before adding any dependency, provider or release step, the implementer must record:

1. whether an account or payment method is required;
2. the current free quota and what happens when it is exhausted;
3. whether overage can be billed automatically;
4. the zero-cost fallback;
5. what functionality is lost on the free tier.

Anything capable of charging money requires explicit owner approval and an update to this file and `DECISIONS.md` before implementation.
