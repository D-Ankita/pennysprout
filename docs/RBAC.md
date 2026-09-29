# PennySprout RBAC

## Roles

- **CHILD**: Gagan in the first beta
- **PARENT**: Mom or Dad
- **ADMIN**: Sister

## Permissions

Legend:
- ✅ Allowed
- ❌ Not allowed
- 🟡 Request only; Admin approval required

| Capability | Child | Parent | Admin |
|---|---:|---:|---:|
| View active tasks | ✅ | ✅ | ✅ |
| View task details and reward | ✅ | ✅ | ✅ |
| Mark task as completed | ✅ | ✅ | ✅ |
| Verify task completion | ❌ | ✅ | ✅ |
| Add new task | 🟡 | ❌ | ✅ |
| Edit existing task | 🟡 | ❌ | ✅ |
| Delete / deactivate task | 🟡 | ❌ | ✅ |
| Suggest reward amount | ✅ | ❌ | ✅ |
| Set / change final task reward | ❌ | ❌ | ✅ |
| Approve / reject task proposal | ❌ | ❌ | ✅ |
| Approve / reject task edit | ❌ | ❌ | ✅ |
| Approve / reject completion reward | ❌ | ❌ | ✅ |
| View completion history | ✅ | ✅ | ✅ |
| View who marked / verified completion | ✅ | ✅ | ✅ |
| View wallet balances | ✅ | ✅ | ✅ |
| View earnings history | ✅ | ✅ | ✅ |
| Add expense | ✅ | ❌ | ✅ |
| Edit/delete posted expense | 🟡 | ❌ | ✅ |
| Categorize expense as Need / Want | ✅ | ❌ | ✅ |
| View expense history | ✅ | ✅ | ✅ |
| Move spendable balance to savings | ✅ | ❌ | ✅ |
| Withdraw from savings | 🟡 | ❌ | ✅ |
| Record cash / UPI payout | ❌ | ❌ | ✅ |
| View savings | ✅ | ✅ | ✅ |
| View savings goals | ✅ | ✅ | ✅ |
| Create savings goal | ✅ | ❌ | ✅ |
| Edit savings goal | ✅ | ❌ | ✅ |
| Delete savings goal | 🟡 | ❌ | ✅ |
| Configure financial rules | ❌ | ❌ | ✅ |
| View reports | ✅ | ✅ | ✅ |
| View display-only streaks | ✅ | ✅ | ✅ |
| Configure recurrence / completion limits | ❌ | ❌ | ✅ |
| Create financial adjustment | ❌ | ❌ | ✅ |
| Manage users and roles | ❌ | ❌ | ✅ |

## Critical Authorization Rules

1. **Only Admin approval may turn task completion into a TASK_REWARD ledger transaction.**
2. Parent verification is optional and informational.
3. Parent verification must never create or release money.
4. The Child cannot approve their own financial reward.
5. Wallet balances are derived from the ledger, not editable numeric fields.
6. All writes must be scoped to the authenticated user's household.
7. UI hiding is not security. Equivalent authorization must be enforced in backend/RLS policies.
8. No authenticated client role receives direct table-write access. Every mutation uses a trusted server function; ledger transactions and postings are never client-writable.
9. A Child may create a pending request, but may not set its review fields or terminal state.
