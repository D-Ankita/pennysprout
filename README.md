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
- [Financial Model and Flows](docs/FINANCIAL_MODEL.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
- [Product and Architecture Decisions](docs/DECISIONS.md)

## MVP scope

The MVP includes task management, completion tracking, optional parent verification, admin reward approval, a virtual wallet, savings, expenses, payout tracking, goals, streaks, reports and notifications.

The MVP does **not** transfer real money, connect to bank accounts, initiate UPI payments, provide investments, or act as a regulated financial product.

## Working brand

**PennySprout**

Working tagline: **Small habits. Smart money.**

Brand and trademark clearance is still pending final official verification before public launch.
