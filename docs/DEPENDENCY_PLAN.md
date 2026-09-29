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
| `react-native-url-polyfill` | `4.0.0` | Supabase React Native URL support |

Install Expo-native modules through `npx expo install` so Expo selects compatible versions:

- `expo-constants`
- `expo-crypto`
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

Use `expo-crypto.randomUUID()` for idempotency keys. Use React Native `StyleSheet` plus local tokens. Do not add NativeWind, Tailwind, Redux, MobX, Zustand, a date library, UUID package, or a component framework. Server SQL owns recurrence/timezone decisions; the client uses `Intl` for display.

## 3. Development and validation dependencies

| Package/tool | Baseline | Purpose |
|---|---:|---|
| Supabase CLI | `2.118.0` | Local stack, migrations and database tests |
| Android SDK/Gradle through Expo | Version selected by Expo SDK 57 | Default local development and signed APK builds |
| EAS CLI | `24.8.0` | Optional Free-plan fallback only; never a paid build or submission path |
| `jest` / `jest-expo` | `29.7.0` / `57.0.5` | Expo SDK 57-compatible unit/component runner and preset |
| `@types/jest` | `29.5.14` | Jest 29 TypeScript types required by Expo SDK 57 |
| `@testing-library/react-native` | `14.0.1` | Behavior-focused component tests |
| `react-test-renderer` | `19.2.3` | Must match locked React version |
| ESLint / `eslint-config-expo` | `9.39.5` / `57.0.2` | Expo SDK 57-compatible static analysis |
| `eslint-import-resolver-typescript` | `3.10.1` | Direct pin so Expo lint can resolve the `@/*` TypeScript path alias under npm's nested dependency layout |
| Prettier | `3.9.9` | Deterministic formatting |
| pgTAP | Version shipped by local Supabase | RLS/function/database tests |
| Maestro | Stable CLI pinned in CI setup | Physical/emulator end-to-end flows |

Expo-managed versions are resolved by the SDK 57 scaffold and `npx expo install --check`; the committed lockfile records the exact result. The initial expected native versions include `expo-network ~57.0.2`, `expo-crypto ~57.0.3`, and `expo-secure-store ~57.0.4`; Expo CLI remains authoritative if a later SDK 57 patch requires a compatible patch adjustment during Phase 0.

Tooling versions must also remain inside Expo SDK 57's supported compatibility range. Do not upgrade Jest or ESLint to a newer major independently: `jest-expo 57` uses Jest 29 internals, while the lint plugins supplied through `eslint-config-expo 57` support ESLint 9 APIs. A newer major may be adopted only with the Expo SDK whose Doctor and lint stack support it.

The lockfile overrides `@react-native/metro-config` to `0.86.3`, matching React Native 0.86.3. This prevents broad transitive ranges from selecting Metro 0.87.x, which npm correctly reports as invalid for React Native's 0.86.3 community CLI plugin.

The lockfile also overrides four transitive packages to the versions Expo SDK 57 ships with, because npm otherwise resolves newer, incompatible releases:

- `react-dom` `19.2.3`: pulled in by `expo-router`; must match the locked React version.
- `react-native-reanimated` `4.5.1` and `react-native-worklets` `0.10.1`: required by `expo-router` through `react-native-drawer-layout`; these are the SDK 57 bundled native versions (`expo-modules-core` rejects worklets above 0.10).
- `test-renderer` `1.2.0`: peer of `@testing-library/react-native` 14; later releases require React 19.3.

Rollback: remove an override only when an Expo SDK upgrade resolves the same package to a compatible version and `npm ls --all`, Expo Doctor and all tests pass.

## 4. Rejected alternatives

- **Expo SDK 58 beta:** rejected because prerelease dependencies are inappropriate for the foundation.
- **Bare React Native:** rejected because it adds native build maintenance without a product requirement.
- **Flutter:** rejected because the approved stack is Expo/TypeScript and the repository already specifies it.
- **Firebase:** rejected because Postgres, RLS and transactional RPC are central to the approved financial model.
- **Redux/global stores:** rejected because server state dominates and TanStack Query plus small contexts are sufficient.
- **UI frameworks:** rejected to avoid generic visuals, upgrade coupling and unused surface area.
- **Direct FCM client/server integration:** rejected for beta; Expo Push Service is adequate and keeps credentials manageable.
- **Expo Go:** rejected as a production-development environment; use development builds.
- **Docker Desktop:** not required; Podman Desktop is the locked free local container runtime.
- **Paid EAS, Supabase, monitoring or hosting plans:** rejected by the zero-cost constraint.
- **Google Play distribution:** rejected for the family release; distribute the signed APK directly.

## 5. External dependencies and owners

| Dependency | Required before | Owner action |
|---|---|---|
| Podman Desktop | Database development | Install and verify the free Docker-compatible runtime locally |
| Android SDK/JDK | First native build | Use the existing local Android toolchain |
| Hosted Supabase Free project | Family acceptance | Owner creates one Free project without a payment method |
| Android keystore | First signed family APK | Generate locally and back up outside Git |
| Firebase/FCM Spark credentials | Push testing | Owner creates a no-cost Spark project without Blaze billing |
| Physical Android device | Beta gate | Install preview APK and test notifications |
| Expo account | Push project registration or optional Free EAS fallback | Keep the account on the non-billable Free plan |

Missing external access blocks only the corresponding environment gate, not unrelated local implementation.

Every dependency and provider must also satisfy [`ZERO_COST_OPERATIONS.md`](ZERO_COST_OPERATIONS.md). Quota exhaustion is a stop condition, not authorization to purchase capacity.

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
