# PennySprout Dependency Plan

Status: **LOCKED BASELINE — 28 September 2026**

The lockfile is authoritative after scaffolding. Exact resolved transitive versions must not be hand-edited. Dependency changes require rationale, compatibility verification, security/license review, and rollback notes.

## 1. Runtime and package manager

| Item | Locked choice | Reason |
|---|---|---|
| Node.js | 24 LTS | Supported LTS; above Expo 57 and Supabase CLI minimums |
| npm | Version bundled with pinned Node; `package-lock.json` committed | Lowest setup burden |
| Expo | `~57.0.25` | Current stable SDK; SDK 58 is beta |
| React Native | `0.86.3` | Expo 57 template-compatible version |
| React | `19.2.3` | Expo 57 compatibility |
| TypeScript | `~6.0.3` | Expo 57 template-compatible version |
| Android | Android 9+; compile/target SDK inherited from Expo 57 | Product support decision and managed compatibility |

Use `.nvmrc` and `package.json.engines` to pin Node 24. CI must use the same major version.

## 2. Application dependencies

| Package | Baseline | Purpose |
|---|---:|---|
| `expo-router` | `~57.0.23` | File-based typed navigation |
| `@supabase/supabase-js` | `2.117.2` | Auth, Data API, Realtime and RPC |
| `@tanstack/react-query` | `5.104.0` | Server cache, retries and invalidation |
| `react-hook-form` | `7.89.0` | Form state |
| `zod` | `4.6.5` | Shared input/output validation |
| `react-native-url-polyfill` | exact latest verified during scaffold | Supabase React Native URL support |
| `uuid` | exact current maintained major verified during scaffold | Mutation idempotency UUIDs |

Install Expo-native modules through `npx expo install` so Expo selects compatible versions:

- `expo-constants`
- `expo-device`
- `expo-linking`
- `expo-network`
- `expo-notifications`
- `expo-secure-store`
- `expo-splash-screen`
- `expo-status-bar`
- `react-native-gesture-handler`
- `react-native-safe-area-context`
- `react-native-screens`

Use React Native `StyleSheet` plus local tokens. Do not add NativeWind, Tailwind, Redux, MobX, Zustand, a date library, or a component framework. Server SQL owns recurrence/timezone decisions; the client uses `Intl` for display.

## 3. Development and validation dependencies

| Package/tool | Baseline | Purpose |
|---|---:|---|
| Supabase CLI | `2.118.0` | Local stack, migrations and database tests |
| EAS CLI | `24.8.0` | Android builds, credentials and submission |
| `jest-expo` | Expo-compatible version | Unit/component runner |
| `@testing-library/react-native` | Compatible stable version | Behavior-focused component tests |
| ESLint | Expo template-compatible version | Static analysis |
| Prettier | `3.9.9` | Deterministic formatting |
| pgTAP | Version shipped by local Supabase | RLS/function/database tests |
| Maestro | Stable CLI pinned in CI setup | Physical/emulator end-to-end flows |

Expo-managed versions are resolved by the SDK 57 scaffold and `npx expo install --check`; the committed lockfile records the exact result.

## 4. Rejected alternatives

- **Expo SDK 58 beta:** rejected because prerelease dependencies are inappropriate for the foundation.
- **Bare React Native:** rejected because it adds native build maintenance without a product requirement.
- **Flutter:** rejected because the approved stack is Expo/TypeScript and the repository already specifies it.
- **Firebase:** rejected because Postgres, RLS and transactional RPC are central to the approved financial model.
- **Redux/global stores:** rejected because server state dominates and TanStack Query plus small contexts are sufficient.
- **UI frameworks:** rejected to avoid generic visuals, upgrade coupling and unused surface area.
- **Direct FCM client/server integration:** rejected for beta; Expo Push Service is adequate and keeps credentials manageable.
- **Expo Go:** rejected as a production-development environment; use development builds.

## 5. External dependencies and owners

| Dependency | Required before | Owner action |
|---|---|---|
| Expo/EAS account | First development build | Owner signs in and owns project |
| Supabase local Docker-compatible runtime | Database development | Install and verify locally |
| Hosted Supabase staging | Family acceptance | Owner creates/links project |
| Hosted Supabase production | Production build | Owner creates separate project |
| Android keystore | First signed preview | Generate through owner EAS account and back up |
| Firebase/FCM v1 credentials | Push testing | Owner creates project/credentials |
| Google Play Console | Closed/public testing | Owner account and app registration |
| Physical Android device | Beta gate | Install preview APK and test notifications |
| Privacy/support pages | Public release | Owner supplies approved content/URLs |

Missing external access blocks only the corresponding environment gate, not unrelated local implementation.

## 6. Dependency change procedure

1. Open a dedicated dependency branch/PR.
2. Read official release notes for the exact range.
3. Check engines, peer dependencies, native changes, licenses and advisories.
4. Update the smallest coherent package set.
5. Run clean install, Expo Doctor, lint, types, tests, database tests, export, Android preview build and physical smoke test when native code changes.
6. Record rollback instructions.

Official compatibility references:

- [Expo SDK version matrix](https://docs.expo.dev/versions/latest/)
- [Expo SDK 57 release](https://expo.dev/changelog/sdk-57)
- [Node.js release status](https://nodejs.org/en/about/previous-releases)
- [Supabase CLI local development](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Expo Android APK builds](https://docs.expo.dev/build-reference/apk/)
