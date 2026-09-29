# PennySprout

PennySprout is a family-focused mobile app that helps children build healthy habits, earn pocket money responsibly, and learn how to save and spend with intention.

The first beta will be tested with Gagan and three supporting family roles:

- **Child - Gagan:** completes tasks, proposes task changes, tracks earnings, savings and expenses.
- **Parent - Mom/Dad:** can mark or optionally verify task completion, but can never create wallet transactions.
- **Admin - Sister:** controls tasks, approvals, reward amounts, payouts and financial rules.

## Core rule

**Task completion -> optional parent verification -> mandatory admin approval -> reward credited**

Parent verification is helpful evidence, not a gate. Only admin approval can create an earning transaction.

## Product principles

1. Reward useful habits without turning every responsibility into a permanent paid chore.
2. Teach the difference between earning, saving, spending and receiving actual cash/UPI.
3. Keep money-changing actions auditable and admin-controlled.
4. Give the child agency through proposals, goals and self-tracking.
5. Keep the first version small enough to beta test with one family, but architect it for multiple households later.

## Planned stack

- React Native with Expo and TypeScript
- Supabase Auth
- Supabase Postgres
- Row Level Security for household and role isolation
- Expo Notifications
- GitHub Actions for checks and release automation

## Developer setup

Prerequisites: Node.js 24 LTS (`.nvmrc`; `engine-strict` is enabled) and the npm version bundled with it. Android is the only approved platform. Use an Expo development build or an Android emulator; Expo Go is not a supported development environment.

```bash
nvm use
npm ci
cp .env.example .env.local
npm run android
```

### Environment

Configuration is validated at startup by `src/config/env.ts`. Missing or invalid values block the app with a configuration error; nothing falls back to another environment.

| Variable                               | Rule                                                                   |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `EXPO_PUBLIC_APP_ENV`                  | `local`, `staging` or `production`                                     |
| `EXPO_PUBLIC_SUPABASE_URL`             | http(s) URL; `staging`/`production` require https and a non-local host |
| `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Publishable key only; secret or service-role keys are rejected         |

`EXPO_PUBLIC_*` values are embedded in the app bundle. Never put secrets in them. `.env` and `.env*.local` are git-ignored.

### Checks

| Command                  | Purpose                                                      |
| ------------------------ | ------------------------------------------------------------ |
| `npm run format:check`   | Prettier (locked docs and migrations are excluded)           |
| `npm run lint`           | ESLint with `eslint-config-expo`, zero warnings              |
| `npm run typecheck`      | Strict TypeScript                                            |
| `npm run test:ci`        | Jest + React Native Testing Library with coverage thresholds |
| `npm run doctor`         | Expo Doctor                                                  |
| `npm run export:android` | Production Android bundle export                             |
| `npm run audit:deps`     | npm audit, failing on high/critical                          |
| `npm run audit:licenses` | Production dependency license allowlist                      |
| `npm run check`          | Format, lint, typecheck and tests together                   |

CI (`.github/workflows/ci.yml`) runs all of the above on Node 24 plus a gitleaks secret scan. The Supabase local stack, database/RLS tests and migration lint are added in Phase 1.

## Documentation

- [Product Requirements](docs/PRD.md)
- [RBAC and permissions](docs/RBAC.md)
- [Technical Design](docs/TRD.md)
- [Exact Database Schema](docs/DATABASE_SCHEMA.md)
- [State Machines](docs/STATE_MACHINES.md)
- [Recurrence Rules](docs/RECURRENCE_RULES.md)
- [Financial Model and Flows](docs/FINANCIAL_MODEL.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
- [Product and Architecture Decisions](docs/DECISIONS.md)
- [Locked Implementation Decisions](docs/DECISION_CLOSURE.md)
- [User Flows and Screens](docs/USER_FLOWS_AND_SCREENS.md)
- [UI Design System](docs/UI_DESIGN_SYSTEM.md)
- [API and Command Contracts](docs/API_CONTRACTS.md)
- [Authentication and Onboarding](docs/AUTH_AND_ONBOARDING.md)
- [Notification Delivery](docs/NOTIFICATIONS.md)
- [Dependency Plan](docs/DEPENDENCY_PLAN.md)
- [Test Plan](docs/TEST_PLAN.md)
- [Build and Release](docs/BUILD_AND_RELEASE.md)
- [Claude Code Implementation Handoff](docs/CLAUDE_IMPLEMENTATION_HANDOFF.md)

## MVP scope

The Android beta includes task management, completion tracking, optional parent verification, admin reward approval, a virtual wallet, savings, expenses, payout tracking, goals, display-only streaks, reports and transactional notifications.

The MVP does **not** transfer real money, connect to bank accounts, initiate UPI payments, provide investments, or act as a regulated financial product.

Web, desktop, Windows, macOS and iOS releases are not part of the approved beta scope.

## Working brand

**PennySprout**

Working tagline: **Small habits. Smart money.**

Brand and trademark clearance is still pending final official verification before public launch.
