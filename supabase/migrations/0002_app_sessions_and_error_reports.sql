-- PennySprout app sessions and client error reports.
-- 1. Enforces the 30-day inactivity sign-out server-side without Supabase's paid
--    session time-box/inactivity feature. Every household authorization helper
--    requires an active, recently used app session keyed to the JWT session_id.
--    Expiry is evaluated lazily on each request; no cleanup job is required.
-- 2. Provides free, restricted, append-only crash reporting stored in Supabase.

create type private.app_session_revoke_reason as enum (
  'SIGNED_OUT', 'INACTIVITY', 'PASSWORD_CHANGED', 'ADMIN_RESET', 'MEMBERSHIP_DISABLED'
);

create table private.app_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoke_reason private.app_session_revoke_reason,
  constraint app_sessions_revocation check (
    (revoked_at is null and revoke_reason is null)
    or (revoked_at is not null and revoke_reason is not null)
  )
);

create index app_sessions_user_active_idx
  on private.app_sessions (user_id)
  where revoked_at is null;
create index app_sessions_retention_idx
  on private.app_sessions ((coalesce(revoked_at, last_activity_at)));

create table private.client_error_reports (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete cascade,
  device_install_id uuid not null,
  error_code text not null check (error_code ~ '^[A-Z][A-Z0-9_]{1,63}$'),
  app_version text not null check (app_version ~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'),
  build_number text not null check (build_number ~ '^[0-9]{1,10}$'),
  environment text not null check (environment in ('local', 'family')),
  platform text not null check (platform = 'android'),
  route text not null check (route ~ '^/[A-Za-z0-9_/()\[\].-]{0,199}$'),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  stack text check (stack is null or char_length(stack) <= 4000)
);

create index client_error_reports_rate_idx
  on private.client_error_reports (user_id, received_at desc);
create index client_error_reports_retention_idx
  on private.client_error_reports (received_at);

create trigger client_error_reports_append_only
before update on private.client_error_reports
for each row execute function public.reject_mutation();

revoke all on all tables in schema private from public, anon, authenticated;

-- Constants and helpers ------------------------------------------------------

create or replace function private.app_session_inactivity_limit()
returns interval
language sql
immutable
set search_path = ''
as $$
  select interval '30 days';
$$;

create or replace function private.current_app_session_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select case
    when auth.jwt() ->> 'session_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (auth.jwt() ->> 'session_id')::uuid
  end;
$$;

create or replace function private.command_error(p_code text, p_message text, p_retryable boolean)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'ok', false,
    'error', jsonb_build_object('code', p_code, 'message', p_message, 'retryable', p_retryable)
  );
$$;

create or replace function private.command_ok(p_data jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('ok', true, 'data', p_data, 'replayed', false);
$$;

create or replace function private.revoke_app_sessions(
  p_user_id uuid,
  p_except_session_id uuid,
  p_reason private.app_session_revoke_reason
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  update private.app_sessions
  set revoked_at = now(), revoke_reason = p_reason
  where user_id = p_user_id
    and revoked_at is null
    and (p_except_session_id is null or session_id <> p_except_session_id);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- A stack is stored only when every line is a recognised frame made of
-- identifiers, bundle-relative paths and line/column numbers.
create or replace function private.is_safe_stack(p_stack text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_stack is not null
    and char_length(p_stack) between 1 and 4000
    and array_length(string_to_array(p_stack, E'\n'), 1) <= 30
    and not exists (
      select 1
      from unnest(string_to_array(p_stack, E'\n')) as frame(line)
      where frame.line !~ '^ {0,8}at [A-Za-z0-9_$.<>?\[\] ]{1,120} \((native|(address at )?[A-Za-z0-9_./-]{1,200}:[0-9]{1,7}:[0-9]{1,7})\)$'
        and frame.line !~ '^ {0,8}at (address at )?[A-Za-z0-9_./-]{1,200}:[0-9]{1,7}:[0-9]{1,7}$'
    );
$$;

revoke all on function private.app_session_inactivity_limit() from public;
revoke all on function private.current_app_session_id() from public;
revoke all on function private.command_error(text, text, boolean) from public;
revoke all on function private.command_ok(jsonb) from public;
revoke all on function private.revoke_app_sessions(uuid, uuid, private.app_session_revoke_reason) from public;
revoke all on function private.is_safe_stack(text) from public;

-- Session check used by every household authorization helper -----------------

create or replace function public.has_active_app_session()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.app_sessions s
    where s.session_id = private.current_app_session_id()
      and s.user_id = auth.uid()
      and s.revoked_at is null
      and s.last_activity_at > now() - private.app_session_inactivity_limit()
  );
$$;

create or replace function public.is_active_household_member(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_active_app_session()
    and exists (
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
  select public.has_active_app_session()
    and exists (
      select 1
      from public.household_members hm
      where hm.household_id = target_household_id
        and hm.user_id = auth.uid()
        and hm.status = 'ACTIVE'
        and hm.role = any(allowed_roles)
    );
$$;

drop policy profiles_select_shared_household on public.profiles;
create policy profiles_select_shared_household on public.profiles
for select to authenticated
using (
  public.has_active_app_session()
  and (
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
  )
);

-- Authenticated session commands --------------------------------------------

create or replace function public.touch_app_session()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_session_id uuid := private.current_app_session_id();
  v_session private.app_sessions%rowtype;
  v_last_activity_at timestamptz;
begin
  if v_user_id is null or v_session_id is null then
    return private.command_error('AUTH_SESSION_EXPIRED', 'Session expired.', false);
  end if;

  select * into v_session
  from private.app_sessions
  where session_id = v_session_id and user_id = v_user_id
  for update;

  if not found or v_session.revoked_at is not null then
    return private.command_error('AUTH_SESSION_EXPIRED', 'Session expired.', false);
  end if;

  if v_session.last_activity_at <= now() - private.app_session_inactivity_limit() then
    update private.app_sessions
    set revoked_at = now(), revoke_reason = 'INACTIVITY'
    where session_id = v_session_id;
    return private.command_error('AUTH_SESSION_EXPIRED', 'Session expired.', false);
  end if;

  if not exists (
    select 1 from public.household_members hm
    where hm.user_id = v_user_id and hm.status = 'ACTIVE'
  ) then
    return private.command_error('MEMBERSHIP_DISABLED', 'Membership is not active.', false);
  end if;

  update private.app_sessions
  set last_activity_at = now()
  where session_id = v_session_id
  returning last_activity_at into v_last_activity_at;

  return private.command_ok(jsonb_build_object('lastActivityAt', v_last_activity_at));
end;
$$;

create or replace function public.end_app_session()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_session_id uuid := private.current_app_session_id();
begin
  if v_user_id is null or v_session_id is null then
    return private.command_error('AUTH_SESSION_EXPIRED', 'Session expired.', false);
  end if;

  update private.app_sessions
  set revoked_at = now(), revoke_reason = 'SIGNED_OUT'
  where session_id = v_session_id and user_id = v_user_id and revoked_at is null;

  return private.command_ok(jsonb_build_object('ended', true));
end;
$$;

-- Service-only gateway functions (called by authentication Edge Functions) ---

create or replace function public.gateway_start_app_session(p_user_id uuid, p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or p_session_id is null then
    raise exception using errcode = '22023', message = 'user and session are required';
  end if;

  insert into private.app_sessions (session_id, user_id)
  values (p_session_id, p_user_id)
  on conflict (session_id) do update
    set last_activity_at = now()
    where private.app_sessions.user_id = excluded.user_id
      and private.app_sessions.revoked_at is null;

  if not found then
    raise exception using errcode = '42501', message = 'app session cannot be started';
  end if;

  -- Lazy, bounded retention: drop sessions that ended more than 90 days ago.
  delete from private.app_sessions
  where session_id in (
    select s.session_id
    from private.app_sessions s
    where coalesce(s.revoked_at, s.last_activity_at) < now() - interval '90 days'
    limit 100
  );
end;
$$;

create or replace function public.gateway_revoke_app_sessions(
  p_user_id uuid,
  p_except_session_id uuid,
  p_reason text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null
    or p_reason is null
    or p_reason not in ('SIGNED_OUT', 'PASSWORD_CHANGED', 'ADMIN_RESET', 'MEMBERSHIP_DISABLED') then
    raise exception using errcode = '22023', message = 'invalid session revocation';
  end if;

  return private.revoke_app_sessions(
    p_user_id, p_except_session_id, p_reason::private.app_session_revoke_reason
  );
end;
$$;

-- Client error reporting -----------------------------------------------------

create or replace function public.report_client_error(
  p_error_code text,
  p_app_version text,
  p_build_number text,
  p_environment text,
  p_platform text,
  p_route text,
  p_occurred_at timestamptz,
  p_stack text,
  p_device_install_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid;
begin
  if v_user_id is null or not public.has_active_app_session() then
    return private.command_error('AUTH_SESSION_EXPIRED', 'Session expired.', false);
  end if;

  if p_error_code is null or p_error_code !~ '^[A-Z][A-Z0-9_]{1,63}$'
    or p_app_version is null or p_app_version !~ '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    or p_build_number is null or p_build_number !~ '^[0-9]{1,10}$'
    or p_environment is null or p_environment not in ('local', 'family')
    or p_platform is null or p_platform <> 'android'
    or p_route is null or p_route !~ '^/[A-Za-z0-9_/()\[\].-]{0,199}$'
    or p_occurred_at is null
    or p_occurred_at < now() - interval '7 days'
    or p_occurred_at > now() + interval '5 minutes'
    or p_device_install_id is null then
    return private.command_error('VALIDATION_FAILED', 'Invalid error report.', false);
  end if;

  -- Serialize per user so concurrent reports cannot exceed the rate limits.
  perform pg_advisory_xact_lock(hashtext('client_error_reports'), hashtext(v_user_id::text));

  if (
    select count(*) from private.client_error_reports r
    where r.user_id = v_user_id
      and r.device_install_id = p_device_install_id
      and r.received_at > now() - interval '1 hour'
  ) >= 10
  or (
    select count(*) from private.client_error_reports r
    where r.user_id = v_user_id
      and r.received_at > now() - interval '1 day'
  ) >= 50 then
    return private.command_ok(jsonb_build_object('accepted', false));
  end if;

  select hm.household_id into v_household_id
  from public.household_members hm
  where hm.user_id = v_user_id and hm.status = 'ACTIVE'
  order by hm.joined_at
  limit 1;

  insert into private.client_error_reports (
    user_id, household_id, device_install_id, error_code, app_version, build_number,
    environment, platform, route, occurred_at, stack
  ) values (
    v_user_id, v_household_id, p_device_install_id, p_error_code, p_app_version, p_build_number,
    p_environment, p_platform, p_route, p_occurred_at,
    case when private.is_safe_stack(p_stack) then p_stack end
  );

  -- Lazy, bounded retention: keep 30 days of reports.
  delete from private.client_error_reports
  where id in (
    select r.id from private.client_error_reports r
    where r.received_at < now() - interval '30 days'
    order by r.received_at
    limit 100
  );

  return private.command_ok(jsonb_build_object('accepted', true));
end;
$$;

-- Grants ----------------------------------------------------------------------

revoke all on function public.has_active_app_session() from public, anon, authenticated;
revoke all on function public.touch_app_session() from public, anon, authenticated;
revoke all on function public.end_app_session() from public, anon, authenticated;
revoke all on function public.gateway_start_app_session(uuid, uuid) from public, anon, authenticated;
revoke all on function public.gateway_revoke_app_sessions(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.report_client_error(
  text, text, text, text, text, text, timestamptz, text, uuid
) from public, anon, authenticated;

grant execute on function public.has_active_app_session() to authenticated;
grant execute on function public.touch_app_session() to authenticated;
grant execute on function public.end_app_session() to authenticated;
grant execute on function public.report_client_error(
  text, text, text, text, text, text, timestamptz, text, uuid
) to authenticated;
grant execute on function public.gateway_start_app_session(uuid, uuid) to service_role;
grant execute on function public.gateway_revoke_app_sessions(uuid, uuid, text) to service_role;
