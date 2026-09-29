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
