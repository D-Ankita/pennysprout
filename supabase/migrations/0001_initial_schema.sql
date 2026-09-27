-- PennySprout initial schema.
-- Financial command functions are intentionally added in later, tested migrations.
-- This migration establishes the data model, invariants, indexes, RLS boundary,
-- and denies all direct client writes to financial history.

create extension if not exists pgcrypto;
create schema if not exists private;

create type public.household_role as enum ('CHILD', 'PARENT', 'ADMIN');
create type public.membership_status as enum ('INVITED', 'ACTIVE', 'DISABLED');
create type public.task_status as enum ('DRAFT', 'ACTIVE', 'INACTIVE');
create type public.task_category as enum ('HOUSEHOLD', 'STUDY', 'HEALTH', 'RESPONSIBILITY', 'KINDNESS', 'OTHER');
create type public.recurrence_type as enum ('ONE_TIME', 'DAILY', 'SELECTED_WEEKDAYS', 'WEEKLY');
create type public.proposal_type as enum ('CREATE', 'UPDATE', 'DEACTIVATE');
create type public.review_status as enum ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');
create type public.completion_status as enum ('PENDING_APPROVAL', 'APPROVED', 'REJECTED');
create type public.need_want as enum ('NEED', 'WANT');
create type public.expense_category as enum ('FOOD', 'SCHOOL', 'TRANSPORT', 'ENTERTAINMENT', 'GIFTS', 'PERSONAL', 'OTHER');
create type public.expense_correction_type as enum ('VOID', 'REPLACE');
create type public.ledger_bucket as enum ('SPENDABLE', 'SAVINGS', 'UNPAID_EARNINGS');
create type public.ledger_transaction_kind as enum (
  'TASK_REWARD',
  'EXPENSE',
  'EXPENSE_REVERSAL',
  'SAVINGS_DEPOSIT',
  'SAVINGS_WITHDRAWAL',
  'PAYOUT',
  'PAYOUT_REVERSAL',
  'ADJUSTMENT'
);
create type public.payout_method as enum ('CASH', 'UPI', 'OTHER');
create type public.goal_status as enum ('ACTIVE', 'COMPLETED', 'ARCHIVED');
create type public.idempotency_status as enum ('IN_PROGRESS', 'COMPLETED', 'FAILED');
create type public.notification_status as enum ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'CANCELLED');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  must_change_password boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.login_identities (
  user_id uuid primary key references auth.users(id) on delete cascade,
  normalized_username text not null unique
    check (normalized_username ~ '^[a-z0-9_.]{3,30}$'),
  synthetic_email text not null unique,
  created_at timestamptz not null default now()
);

create table private.login_controls (
  normalized_username text primary key
    check (normalized_username ~ '^[a-z0-9_.]{3,30}$'),
  failed_attempts smallint not null default 0 check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  last_failed_at timestamptz,
  updated_at timestamptz not null default now()
);

revoke all on schema private from public, anon, authenticated;
revoke all on all tables in schema private from public, anon, authenticated;

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  currency_code text not null default 'INR' check (currency_code ~ '^[A-Z]{3}$'),
  timezone text not null default 'Asia/Kolkata' check (char_length(timezone) between 1 and 100),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  role public.household_role not null,
  status public.membership_status not null default 'INVITED',
  invited_by uuid references auth.users(id),
  invited_at timestamptz not null default now(),
  joined_at timestamptz,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (household_id, user_id),
  constraint household_members_status_dates check (
    (status = 'INVITED' and joined_at is null and disabled_at is null)
    or (status = 'ACTIVE' and joined_at is not null and disabled_at is null)
    or (status = 'DISABLED' and disabled_at is not null)
  )
);

create index household_members_user_status_idx
  on public.household_members (user_id, status, household_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text check (description is null or char_length(description) <= 1000),
  category public.task_category not null,
  reward_minor bigint not null check (reward_minor >= 0),
  status public.task_status not null default 'DRAFT',
  recurrence public.recurrence_type not null,
  recurrence_interval smallint not null default 1 check (recurrence_interval = 1),
  recurrence_anchor_date date not null,
  completion_limit smallint not null default 1 check (completion_limit between 1 and 5),
  version integer not null default 1 check (version > 0),
  created_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  activated_at timestamptz,
  deactivated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  constraint tasks_status_dates check (
    (status = 'DRAFT' and activated_at is null and deactivated_at is null)
    or (status = 'ACTIVE' and activated_at is not null and deactivated_at is null)
    or (status = 'INACTIVE' and activated_at is not null and deactivated_at is not null)
  )
);

create index tasks_household_status_idx on public.tasks (household_id, status, created_at desc);

create table public.task_schedule_weekdays (
  task_id uuid not null references public.tasks(id) on delete cascade,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  primary key (task_id, iso_weekday)
);

create table public.task_proposals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  task_id uuid,
  proposal_type public.proposal_type not null,
  base_task_version integer check (base_task_version is null or base_task_version > 0),
  proposed_title text check (proposed_title is null or char_length(btrim(proposed_title)) between 1 and 120),
  proposed_description text check (proposed_description is null or char_length(proposed_description) <= 1000),
  proposed_category public.task_category,
  proposed_reward_minor bigint check (proposed_reward_minor is null or proposed_reward_minor >= 0),
  proposed_recurrence public.recurrence_type,
  proposed_recurrence_interval smallint check (proposed_recurrence_interval is null or proposed_recurrence_interval = 1),
  proposed_recurrence_anchor_date date,
  proposed_completion_limit smallint check (proposed_completion_limit is null or proposed_completion_limit between 1 and 5),
  proposed_weekdays smallint[],
  requested_by uuid not null references auth.users(id),
  request_note text check (request_note is null or char_length(request_note) <= 1000),
  status public.review_status not null default 'PENDING',
  reviewed_by uuid references auth.users(id),
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (household_id, task_id) references public.tasks(household_id, id) on delete restrict,
  foreign key (household_id, requested_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint task_proposals_target check (
    (proposal_type = 'CREATE' and task_id is null and base_task_version is null)
    or (proposal_type in ('UPDATE', 'DEACTIVATE') and task_id is not null and base_task_version is not null)
  ),
  constraint task_proposals_create_fields check (
    proposal_type <> 'CREATE'
    or (
      proposed_title is not null
      and proposed_category is not null
      and proposed_reward_minor is not null
      and proposed_recurrence is not null
      and proposed_recurrence_anchor_date is not null
      and proposed_completion_limit is not null
    )
  ),
  constraint task_proposals_weekdays check (
    proposed_weekdays is null
    or proposed_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ),
  constraint task_proposals_review check (
    (status = 'PENDING' and reviewed_by is null and reviewed_at is null)
    or (status = 'CANCELLED' and reviewed_by is null and reviewed_at is not null)
    or (status in ('APPROVED', 'REJECTED') and reviewed_by is not null and reviewed_at is not null)
  )
);

create index task_proposals_household_pending_idx
  on public.task_proposals (household_id, created_at)
  where status = 'PENDING';

create table public.task_completions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  task_id uuid not null,
  child_user_id uuid not null,
  marked_by uuid not null references auth.users(id),
  completed_at timestamptz not null,
  occurrence_local_date date not null,
  occurrence_key text not null check (char_length(occurrence_key) between 1 and 80),
  occurrence_sequence smallint not null check (occurrence_sequence between 1 and 8),
  task_title_snapshot text not null,
  task_version_snapshot integer not null check (task_version_snapshot > 0),
  default_reward_minor bigint not null check (default_reward_minor >= 0),
  status public.completion_status not null default 'PENDING_APPROVAL',
  approved_reward_minor bigint check (approved_reward_minor is null or approved_reward_minor >= 0),
  reviewed_by uuid references auth.users(id),
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  unique (task_id, child_user_id, occurrence_key, occurrence_sequence),
  foreign key (household_id, task_id) references public.tasks(household_id, id) on delete restrict,
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, marked_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint task_completions_review check (
    (status = 'PENDING_APPROVAL' and approved_reward_minor is null and reviewed_by is null and reviewed_at is null)
    or (status = 'APPROVED' and approved_reward_minor is not null and reviewed_by is not null and reviewed_at is not null)
    or (status = 'REJECTED' and approved_reward_minor is null and reviewed_by is not null and reviewed_at is not null)
  )
);

create index task_completions_household_pending_idx
  on public.task_completions (household_id, created_at)
  where status = 'PENDING_APPROVAL';
create index task_completions_child_history_idx
  on public.task_completions (household_id, child_user_id, completed_at desc);

create table public.completion_verifications (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  completion_id uuid not null,
  verifier_user_id uuid not null,
  note text check (note is null or char_length(note) <= 1000),
  verified_at timestamptz not null default now(),
  unique (completion_id, verifier_user_id),
  foreign key (household_id, completion_id) references public.task_completions(household_id, id) on delete restrict,
  foreign key (household_id, verifier_user_id) references public.household_members(household_id, user_id) on delete restrict
);

create table public.ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  child_user_id uuid not null,
  kind public.ledger_transaction_kind not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  description text not null check (char_length(btrim(description)) between 1 and 500),
  reference_table text,
  reference_id uuid,
  reverses_transaction_id uuid references public.ledger_transactions(id) on delete restrict,
  created_by uuid not null references auth.users(id),
  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  unique (household_id, id),
  unique (household_id, id, child_user_id),
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, created_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint ledger_transactions_reference_pair check (
    (reference_table is null) = (reference_id is null)
  ),
  constraint ledger_transactions_reversal_shape check (
    (kind in ('EXPENSE_REVERSAL', 'PAYOUT_REVERSAL') and reverses_transaction_id is not null)
    or (kind not in ('EXPENSE_REVERSAL', 'PAYOUT_REVERSAL') and reverses_transaction_id is null)
  ),
  constraint ledger_transactions_zero_amount check (
    amount_minor > 0 or kind = 'TASK_REWARD'
  )
);

create unique index ledger_transactions_business_reference_uidx
  on public.ledger_transactions (household_id, kind, reference_table, reference_id)
  where reference_id is not null;
create unique index ledger_transactions_reversal_uidx
  on public.ledger_transactions (household_id, kind, reverses_transaction_id)
  where reverses_transaction_id is not null;
create index ledger_transactions_child_effective_idx
  on public.ledger_transactions (household_id, child_user_id, effective_at desc, id);

create table public.ledger_postings (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.ledger_transactions(id) on delete restrict,
  household_id uuid not null,
  child_user_id uuid not null,
  bucket public.ledger_bucket not null,
  amount_minor bigint not null check (amount_minor <> 0),
  created_at timestamptz not null default now(),
  unique (transaction_id, bucket),
  foreign key (household_id, transaction_id, child_user_id) references public.ledger_transactions(household_id, id, child_user_id) on delete restrict,
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict
);

create index ledger_postings_balance_idx
  on public.ledger_postings (household_id, child_user_id, bucket);

create table public.expense_correction_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  child_user_id uuid not null,
  expense_transaction_id uuid not null,
  correction_type public.expense_correction_type not null,
  reason text not null check (char_length(btrim(reason)) between 1 and 1000),
  replacement_amount_minor bigint check (replacement_amount_minor is null or replacement_amount_minor > 0),
  replacement_description text check (replacement_description is null or char_length(btrim(replacement_description)) between 1 and 500),
  replacement_category public.expense_category,
  replacement_need_want public.need_want,
  replacement_expense_date date,
  requested_by uuid not null,
  status public.review_status not null default 'PENDING',
  reviewed_by uuid,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  unique (household_id, id, child_user_id),
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, expense_transaction_id, child_user_id) references public.ledger_transactions(household_id, id, child_user_id) on delete restrict,
  foreign key (household_id, requested_by) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, reviewed_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint expense_correction_replacement check (
    (correction_type = 'VOID' and replacement_amount_minor is null and replacement_description is null and replacement_category is null and replacement_need_want is null and replacement_expense_date is null)
    or (correction_type = 'REPLACE' and replacement_amount_minor is not null and replacement_description is not null and replacement_category is not null and replacement_need_want is not null and replacement_expense_date is not null)
  ),
  constraint expense_correction_review check (
    (status = 'PENDING' and reviewed_by is null and reviewed_at is null)
    or (status = 'CANCELLED' and reviewed_by is null and reviewed_at is not null)
    or (status in ('APPROVED', 'REJECTED') and reviewed_by is not null and reviewed_at is not null)
  )
);

create unique index expense_correction_one_pending_idx
  on public.expense_correction_requests (expense_transaction_id)
  where status = 'PENDING';

create table public.savings_withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  child_user_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  reason text not null check (char_length(btrim(reason)) between 1 and 1000),
  requested_by uuid not null,
  status public.review_status not null default 'PENDING',
  reviewed_by uuid,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, requested_by) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, reviewed_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint savings_withdrawal_review check (
    (status = 'PENDING' and reviewed_by is null and reviewed_at is null)
    or (status = 'CANCELLED' and reviewed_by is null and reviewed_at is not null)
    or (status in ('APPROVED', 'REJECTED') and reviewed_by is not null and reviewed_at is not null)
  )
);

create index savings_withdrawal_pending_idx
  on public.savings_withdrawal_requests (household_id, created_at)
  where status = 'PENDING';

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  child_user_id uuid not null,
  name text not null check (char_length(btrim(name)) between 1 and 100),
  target_minor bigint not null check (target_minor > 0),
  status public.goal_status not null default 'ACTIVE',
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  unique (household_id, id, child_user_id),
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, created_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint savings_goals_archive_date check (
    (status = 'ARCHIVED' and archived_at is not null)
    or (status <> 'ARCHIVED' and archived_at is null)
  )
);

create table public.savings_goal_allocations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  child_user_id uuid not null,
  goal_id uuid not null,
  transaction_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  created_at timestamptz not null default now(),
  foreign key (household_id, goal_id, child_user_id) references public.savings_goals(household_id, id, child_user_id) on delete restrict,
  foreign key (household_id, transaction_id, child_user_id) references public.ledger_transactions(household_id, id, child_user_id) on delete restrict,
  unique (goal_id, transaction_id)
);

create table public.goal_archive_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete restrict,
  goal_id uuid not null,
  child_user_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 1 and 1000),
  requested_by uuid not null,
  status public.review_status not null default 'PENDING',
  reviewed_by uuid,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  foreign key (household_id, goal_id, child_user_id) references public.savings_goals(household_id, id, child_user_id) on delete restrict,
  foreign key (household_id, child_user_id) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, requested_by) references public.household_members(household_id, user_id) on delete restrict,
  foreign key (household_id, reviewed_by) references public.household_members(household_id, user_id) on delete restrict,
  constraint goal_archive_review check (
    (status = 'PENDING' and reviewed_by is null and reviewed_at is null)
    or (status = 'CANCELLED' and reviewed_by is null and reviewed_at is not null)
    or (status in ('APPROVED', 'REJECTED') and reviewed_by is not null and reviewed_at is not null)
  )
);

create unique index goal_archive_one_pending_idx
  on public.goal_archive_requests (goal_id)
  where status = 'PENDING';

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  expo_push_token text not null unique check (char_length(expo_push_token) between 10 and 300),
  device_label text check (device_label is null or char_length(device_label) <= 100),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_tokens_disabled check (
    (is_active and disabled_at is null)
    or (not is_active and disabled_at is not null)
  )
);

create table public.notification_outbox (
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete restrict,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (char_length(event_type) between 1 and 100),
  entity_type text,
  entity_id uuid,
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 500),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  deduplication_key text not null check (char_length(deduplication_key) between 1 and 200),
  status public.notification_status not null default 'PENDING',
  attempt_count smallint not null default 0 check (attempt_count between 0 and 20),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (household_id, recipient_user_id, deduplication_key)
);

create index notification_outbox_dispatch_idx
  on public.notification_outbox (available_at, id)
  where status in ('PENDING', 'FAILED');

create table public.idempotency_keys (
  household_id uuid not null references public.households(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  key uuid not null,
  command text not null check (char_length(command) between 1 and 100),
  request_hash text not null check (request_hash ~ '^[a-f0-9]{64}$'),
  status public.idempotency_status not null default 'IN_PROGRESS',
  result_entity_type text,
  result_entity_id uuid,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (household_id, actor_user_id, key),
  constraint idempotency_completion check (
    (status = 'IN_PROGRESS' and completed_at is null)
    or (status in ('COMPLETED', 'FAILED') and completed_at is not null)
  )
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete restrict,
  event_type text not null check (char_length(event_type) between 1 and 100),
  entity_type text not null check (char_length(entity_type) between 1 and 100),
  entity_id uuid,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now()
);

create index audit_events_household_created_idx
  on public.audit_events (household_id, created_at desc, id desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger households_set_updated_at before update on public.households
for each row execute function public.set_updated_at();
create trigger household_members_set_updated_at before update on public.household_members
for each row execute function public.set_updated_at();
create trigger tasks_set_updated_at before update on public.tasks
for each row execute function public.set_updated_at();
create trigger task_proposals_set_updated_at before update on public.task_proposals
for each row execute function public.set_updated_at();
create trigger task_completions_set_updated_at before update on public.task_completions
for each row execute function public.set_updated_at();
create trigger expense_corrections_set_updated_at before update on public.expense_correction_requests
for each row execute function public.set_updated_at();
create trigger savings_withdrawals_set_updated_at before update on public.savings_withdrawal_requests
for each row execute function public.set_updated_at();
create trigger savings_goals_set_updated_at before update on public.savings_goals
for each row execute function public.set_updated_at();
create trigger goal_archive_requests_set_updated_at before update on public.goal_archive_requests
for each row execute function public.set_updated_at();
create trigger push_tokens_set_updated_at before update on public.push_tokens
for each row execute function public.set_updated_at();

create or replace function public.reject_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'immutable financial or audit record';
end;
$$;

create trigger ledger_transactions_immutable
before update or delete on public.ledger_transactions
for each row execute function public.reject_mutation();
create trigger ledger_postings_immutable
before update or delete on public.ledger_postings
for each row execute function public.reject_mutation();
create trigger audit_events_immutable
before update or delete on public.audit_events
for each row execute function public.reject_mutation();
create trigger notification_outbox_no_delete
before delete on public.notification_outbox
for each row execute function public.reject_mutation();

create or replace function public.is_active_household_member(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
      and hm.status = 'ACTIVE'
  );
$$;

create or replace function public.has_household_role(target_household_id uuid, allowed_roles public.household_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
      and hm.status = 'ACTIVE'
      and hm.role = any(allowed_roles)
  );
$$;

revoke all on function public.is_active_household_member(uuid) from public;
revoke all on function public.has_household_role(uuid, public.household_role[]) from public;
grant execute on function public.is_active_household_member(uuid) to authenticated;
grant execute on function public.has_household_role(uuid, public.household_role[]) to authenticated;

create view public.wallet_balances
with (security_invoker = true)
as
select
  household_id,
  child_user_id,
  coalesce(sum(amount_minor) filter (where bucket = 'SPENDABLE'), 0)::bigint as spendable_minor,
  coalesce(sum(amount_minor) filter (where bucket = 'SAVINGS'), 0)::bigint as savings_minor,
  coalesce(sum(amount_minor) filter (where bucket = 'UNPAID_EARNINGS'), 0)::bigint as unpaid_earnings_minor
from public.ledger_postings
group by household_id, child_user_id;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.tasks enable row level security;
alter table public.task_schedule_weekdays enable row level security;
alter table public.task_proposals enable row level security;
alter table public.task_completions enable row level security;
alter table public.completion_verifications enable row level security;
alter table public.ledger_transactions enable row level security;
alter table public.ledger_postings enable row level security;
alter table public.expense_correction_requests enable row level security;
alter table public.savings_withdrawal_requests enable row level security;
alter table public.savings_goals enable row level security;
alter table public.savings_goal_allocations enable row level security;
alter table public.goal_archive_requests enable row level security;
alter table public.push_tokens enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_select_shared_household on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.household_members mine
    join public.household_members theirs on theirs.household_id = mine.household_id
    where mine.user_id = auth.uid()
      and mine.status = 'ACTIVE'
      and theirs.user_id = profiles.id
      and theirs.status = 'ACTIVE'
  )
);
create policy profiles_update_self on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy households_select_member on public.households
for select to authenticated using (public.is_active_household_member(id));
create policy household_members_select_member on public.household_members
for select to authenticated using (public.is_active_household_member(household_id));

create policy tasks_select_member on public.tasks
for select to authenticated using (public.is_active_household_member(household_id));
create policy task_weekdays_select_member on public.task_schedule_weekdays
for select to authenticated using (
  exists (
    select 1 from public.tasks t
    where t.id = task_schedule_weekdays.task_id
      and public.is_active_household_member(t.household_id)
  )
);

create policy task_proposals_select_member on public.task_proposals
for select to authenticated using (public.is_active_household_member(household_id));
create policy task_proposals_child_insert on public.task_proposals
for insert to authenticated with check (
  requested_by = auth.uid()
  and status = 'PENDING'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);

create policy task_completions_select_member on public.task_completions
for select to authenticated using (public.is_active_household_member(household_id));
create policy completion_verifications_select_member on public.completion_verifications
for select to authenticated using (public.is_active_household_member(household_id));

create policy ledger_transactions_select_member on public.ledger_transactions
for select to authenticated using (public.is_active_household_member(household_id));
create policy ledger_postings_select_member on public.ledger_postings
for select to authenticated using (public.is_active_household_member(household_id));

create policy expense_corrections_select_member on public.expense_correction_requests
for select to authenticated using (public.is_active_household_member(household_id));
create policy expense_corrections_child_insert on public.expense_correction_requests
for insert to authenticated with check (
  requested_by = auth.uid()
  and child_user_id = auth.uid()
  and status = 'PENDING'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);

create policy savings_withdrawals_select_member on public.savings_withdrawal_requests
for select to authenticated using (public.is_active_household_member(household_id));
create policy savings_withdrawals_child_insert on public.savings_withdrawal_requests
for insert to authenticated with check (
  requested_by = auth.uid()
  and child_user_id = auth.uid()
  and status = 'PENDING'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);

create policy savings_goals_select_member on public.savings_goals
for select to authenticated using (public.is_active_household_member(household_id));
create policy savings_goals_child_insert on public.savings_goals
for insert to authenticated with check (
  created_by = auth.uid()
  and child_user_id = auth.uid()
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);
create policy savings_goals_child_update on public.savings_goals
for update to authenticated
using (
  child_user_id = auth.uid()
  and status <> 'ARCHIVED'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
)
with check (
  child_user_id = auth.uid()
  and status <> 'ARCHIVED'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);
create policy savings_allocations_select_member on public.savings_goal_allocations
for select to authenticated using (public.is_active_household_member(household_id));
create policy goal_archive_requests_select_member on public.goal_archive_requests
for select to authenticated using (public.is_active_household_member(household_id));
create policy goal_archive_requests_child_insert on public.goal_archive_requests
for insert to authenticated with check (
  requested_by = auth.uid()
  and child_user_id = auth.uid()
  and status = 'PENDING'
  and public.has_household_role(household_id, array['CHILD']::public.household_role[])
);
create policy push_tokens_select_self on public.push_tokens
for select to authenticated using (user_id = auth.uid());
create policy push_tokens_insert_self on public.push_tokens
for insert to authenticated with check (user_id = auth.uid());
create policy push_tokens_update_self on public.push_tokens
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notification_outbox_select_recipient on public.notification_outbox
for select to authenticated using (
  recipient_user_id = auth.uid()
  and public.is_active_household_member(household_id)
);
create policy audit_events_select_member on public.audit_events
for select to authenticated using (public.is_active_household_member(household_id));

-- Authenticated clients receive read access where RLS permits it. There are no
-- client INSERT/UPDATE/DELETE grants for ledger, posting, idempotency, or audit
-- tables. Later SECURITY DEFINER command functions own those writes.
grant select on public.profiles, public.households, public.household_members,
  public.tasks, public.task_schedule_weekdays, public.task_proposals,
  public.task_completions, public.completion_verifications,
  public.ledger_transactions, public.ledger_postings,
  public.expense_correction_requests, public.savings_withdrawal_requests,
  public.savings_goals, public.savings_goal_allocations,
  public.goal_archive_requests,
  public.push_tokens, public.notification_outbox, public.audit_events,
  public.wallet_balances to authenticated;

grant update (display_name) on public.profiles to authenticated;
grant insert on public.task_proposals, public.expense_correction_requests,
  public.savings_withdrawal_requests, public.savings_goals,
  public.goal_archive_requests to authenticated;
grant update (name, target_minor) on public.savings_goals to authenticated;
grant insert on public.push_tokens to authenticated;
grant update (expo_push_token, device_label, is_active, last_seen_at, disabled_at)
  on public.push_tokens to authenticated;

revoke all on public.ledger_transactions, public.ledger_postings,
  public.idempotency_keys, public.notification_outbox, public.audit_events
  from anon, authenticated;
grant select on public.ledger_transactions, public.ledger_postings,
  public.notification_outbox, public.audit_events to authenticated;
