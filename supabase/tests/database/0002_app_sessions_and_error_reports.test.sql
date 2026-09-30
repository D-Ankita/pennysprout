-- pgTAP coverage for supabase/migrations/0002_app_sessions_and_error_reports.sql.
begin;

create extension if not exists pgtap with schema extensions;

select plan(51);

-- Fixtures --------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.invalid'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.invalid'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.invalid'),
  ('00000000-0000-0000-0000-00000000000d', 'd@test.invalid');

insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Admin One'),
  ('00000000-0000-0000-0000-00000000000b', 'Child One'),
  ('00000000-0000-0000-0000-00000000000c', 'Admin Two'),
  ('00000000-0000-0000-0000-00000000000d', 'Parent Disabled');

insert into public.households (id, name, created_by) values
  ('10000000-0000-0000-0000-000000000001', 'Household One', '00000000-0000-0000-0000-00000000000a'),
  ('10000000-0000-0000-0000-000000000002', 'Household Two', '00000000-0000-0000-0000-00000000000c');

insert into public.household_members (household_id, user_id, role, status, joined_at, disabled_at) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'ADMIN', 'ACTIVE', now(), null),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'CHILD', 'ACTIVE', now(), null),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000c', 'ADMIN', 'ACTIVE', now(), null),
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000d', 'PARENT', 'DISABLED', now(), now());

create function pg_temp.act_as(p_user uuid, p_session uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated', 'session_id', p_session)::text,
    true
  );
$$;

-- Grants and exposure -----------------------------------------------------------

select ok(not has_table_privilege('authenticated', 'private.app_sessions', 'select'),
  'authenticated cannot read app sessions');
select ok(not has_table_privilege('authenticated', 'private.client_error_reports', 'select'),
  'authenticated cannot read error reports');
select ok(not has_table_privilege('authenticated', 'private.client_error_reports', 'insert'),
  'authenticated cannot insert error reports directly');
select ok(not has_function_privilege('authenticated', 'public.gateway_start_app_session(uuid, uuid)', 'execute'),
  'authenticated cannot start app sessions');
select ok(not has_function_privilege('anon', 'public.gateway_start_app_session(uuid, uuid)', 'execute'),
  'anon cannot start app sessions');
select ok(not has_function_privilege('authenticated', 'public.gateway_revoke_app_sessions(uuid, uuid, text)', 'execute'),
  'authenticated cannot revoke app sessions through the gateway');
select ok(has_function_privilege('service_role', 'public.gateway_start_app_session(uuid, uuid)', 'execute'),
  'service_role can start app sessions');
select ok(has_function_privilege('service_role', 'public.gateway_revoke_app_sessions(uuid, uuid, text)', 'execute'),
  'service_role can revoke app sessions');
select ok(has_function_privilege('authenticated', 'public.touch_app_session()', 'execute'),
  'authenticated can touch its session');
select ok(not has_function_privilege('anon', 'public.touch_app_session()', 'execute'),
  'anon cannot touch sessions');
select ok(not has_function_privilege('anon', 'public.end_app_session()', 'execute'),
  'anon cannot end sessions');
select ok(has_function_privilege('authenticated',
  'public.report_client_error(text, text, text, text, text, text, timestamptz, text, uuid)', 'execute'),
  'authenticated can report client errors');
select ok(not has_function_privilege('anon',
  'public.report_client_error(text, text, text, text, text, text, timestamptz, text, uuid)', 'execute'),
  'anon cannot report client errors');

-- Session gate on household authorization ---------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b1');
select ok(not public.is_active_household_member('10000000-0000-0000-0000-000000000001'),
  'active membership without an app session is not authorized');

set local role service_role;
select lives_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b1') $$,
  'gateway starts an app session');
select throws_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000c', '20000000-0000-0000-0000-0000000000b1') $$,
  '42501', 'app session cannot be started',
  'a session id cannot be claimed by another user');
select throws_ok(
  $$ select public.gateway_start_app_session(null, '20000000-0000-0000-0000-0000000000b9') $$,
  '22023', 'user and session are required',
  'gateway requires a user');
select lives_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000c', '20000000-0000-0000-0000-0000000000c1') $$,
  'gateway starts a session for the unrelated household admin');
reset role;

select ok(public.is_active_household_member('10000000-0000-0000-0000-000000000001'),
  'active membership with an active app session is authorized');
select ok(public.has_household_role('10000000-0000-0000-0000-000000000001', array['CHILD']::public.household_role[]),
  'role check passes with an active app session');
select ok(not public.is_active_household_member('10000000-0000-0000-0000-000000000002'),
  'an app session does not grant access to another household');

set local role authenticated;
select is((select count(*)::int from public.households), 1, 'RLS exposes the member household only');
select is((select count(*)::int from public.profiles), 2,
  'profiles of active household members are visible with an active app session');
reset role;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000c1');
select ok(not public.has_active_app_session(), 'another user''s session id is rejected');
set local role authenticated;
select is((select count(*)::int from public.households), 0, 'RLS hides households under a mismatched session');
select is((select count(*)::int from public.profiles), 0, 'RLS hides profiles under a mismatched session');
reset role;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated","session_id":"not-a-uuid"}', true);
select ok(not public.has_active_app_session(), 'a malformed session id is rejected');

-- Touch and 30-day inactivity -------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b1');
update private.app_sessions
set last_activity_at = now() - interval '29 days 23 hours'
where session_id = '20000000-0000-0000-0000-0000000000b1';
select ok(public.has_active_app_session(), 'a session used within 30 days is active');

set local role authenticated;
select is((public.touch_app_session() ->> 'ok')::boolean, true, 'touch succeeds inside the window');
reset role;
select is(
  (select last_activity_at from private.app_sessions where session_id = '20000000-0000-0000-0000-0000000000b1'),
  now(), 'touch refreshes last activity');

update private.app_sessions
set last_activity_at = now() - interval '30 days'
where session_id = '20000000-0000-0000-0000-0000000000b1';
select ok(not public.has_active_app_session(), 'a session idle for 30 days is rejected lazily');
select ok(not public.is_active_household_member('10000000-0000-0000-0000-000000000001'),
  'household authorization fails after 30 idle days');

set local role authenticated;
select is(public.touch_app_session() -> 'error' ->> 'code', 'AUTH_SESSION_EXPIRED',
  'touch reports an expired session');
reset role;
select is(
  (select revoke_reason::text from private.app_sessions where session_id = '20000000-0000-0000-0000-0000000000b1'),
  'INACTIVITY', 'touch records inactivity revocation');

set local role service_role;
select throws_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b1') $$,
  '42501', 'app session cannot be started',
  'a revoked session cannot be revived');
select lives_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b2') $$,
  'signing in again starts a new session');
reset role;

-- Disabled membership --------------------------------------------------------------

set local role service_role;
select lives_ok(
  $$ select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000d', '20000000-0000-0000-0000-0000000000d1') $$,
  'disabled member session row can exist');
reset role;
select pg_temp.act_as('00000000-0000-0000-0000-00000000000d', '20000000-0000-0000-0000-0000000000d1');
set local role authenticated;
select is(public.touch_app_session() -> 'error' ->> 'code', 'MEMBERSHIP_DISABLED',
  'touch reports disabled membership');
reset role;

-- Revocation -----------------------------------------------------------------------

set local role service_role;
select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a1');
select public.gateway_start_app_session('00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a2');
select is(
  public.gateway_revoke_app_sessions('00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a1', 'PASSWORD_CHANGED'),
  1, 'password change revokes other sessions only');
select throws_ok(
  $$ select public.gateway_revoke_app_sessions('00000000-0000-0000-0000-00000000000a', null, 'INACTIVITY') $$,
  '22023', 'invalid session revocation',
  'the gateway cannot record inactivity revocations');
reset role;

select pg_temp.act_as('00000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a1');
select ok(public.has_active_app_session(), 'the current session survives a password change');
set local role authenticated;
select is((public.end_app_session() ->> 'ok')::boolean, true, 'sign-out ends the current session');
reset role;
select ok(not public.has_active_app_session(), 'an ended session is rejected');

-- Client error reports --------------------------------------------------------------

select pg_temp.act_as('00000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-0000000000b2');
set local role authenticated;
select is(
  public.report_client_error('RENDER_FAILED', '0.1.0', '1', 'family', 'android', '/(child)/wallet',
    now(), E'at render (index.android.bundle:1:2345)\nat anonymous (native)', '30000000-0000-0000-0000-000000000001')
    -> 'data' ->> 'accepted',
  'true', 'a valid report is accepted');
select is(
  public.report_client_error('RENDER_FAILED', '0.1.0', '1', 'family', 'android', '/(child)/wallet',
    now(), 'TypeError: amount 500 for user gagan', '30000000-0000-0000-0000-000000000001')
    -> 'data' ->> 'accepted',
  'true', 'a report with an unsafe stack is accepted without the stack');
select is(
  public.report_client_error('render failed', '0.1.0', '1', 'family', 'android', '/wallet',
    now(), null, '30000000-0000-0000-0000-000000000001') -> 'error' ->> 'code',
  'VALIDATION_FAILED', 'free-form error codes are rejected');
select is(
  public.report_client_error('RENDER_FAILED', '0.1.0', '1', 'production', 'android', '/wallet',
    now(), null, '30000000-0000-0000-0000-000000000001') -> 'error' ->> 'code',
  'VALIDATION_FAILED', 'only local and family environments are accepted');
reset role;

select is(
  (select array_agg(stack is not null order by id) from private.client_error_reports),
  array[true, false], 'only the sanitized stack is stored');
select is(
  (select household_id from private.client_error_reports limit 1),
  '10000000-0000-0000-0000-000000000001'::uuid, 'household is derived server-side');

set local role authenticated;
select is(
  (select count(*)::int from generate_series(1, 9) as g(n)
   where public.report_client_error('RENDER_FAILED', '0.1.0', '1', 'family', 'android', '/wallet',
     now(), null, '30000000-0000-0000-0000-000000000001') -> 'data' ->> 'accepted' = 'true'),
  8, 'reports beyond ten per device per hour are dropped');
reset role;

-- Retention: backdated rows are removed by the next accepted report.
insert into private.client_error_reports (
  user_id, device_install_id, error_code, app_version, build_number, environment, platform,
  route, occurred_at, received_at
) values (
  '00000000-0000-0000-0000-00000000000b', '30000000-0000-0000-0000-000000000009', 'OLD_ERROR',
  '0.1.0', '1', 'family', 'android', '/wallet', now() - interval '40 days', now() - interval '31 days'
);
set local role authenticated;
select public.report_client_error('RENDER_FAILED', '0.1.0', '1', 'family', 'android', '/wallet',
  now(), null, '30000000-0000-0000-0000-000000000002');
reset role;
select is(
  (select count(*)::int from private.client_error_reports where error_code = 'OLD_ERROR'),
  0, 'reports older than 30 days are removed lazily');

select * from finish();
rollback;
