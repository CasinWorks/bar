-- Diagnose "the guest never got the welcome page".
--
-- Read-only. Paste into the Supabase SQL editor, put the guest's email on the
-- line below, and run. Every row is a check with a PASS / FAIL verdict.
--
-- The welcome needs all of these to hold at once:
--   1. an event_guests row for that member, status = 'checked_in'
--   2. the event still on (not ended, and live or starting today in Manila)
--   3. the event branch matching the member's club session branch
--   4. the member's session phase = 'inside_club'
--   5. the app able to read the row (list_my_event_invites / get_active_event)

with params as (
  select lower(trim('GUEST_EMAIL_HERE')) as email
),
member as (
  select p.id, p.email, p.role
  from public.profiles p, params
  where lower(trim(p.email)) = params.email
),
fn as (
  select
    (select pg_get_functiondef(p.oid)
       from pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and p.proname = 'list_my_event_invites'
      limit 1) as invites_def,
    (select pg_get_functiondef(p.oid)
       from pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and p.proname = 'get_active_event_for_member'
      limit 1) as active_def
),
session as (
  select cs.phase, nullif(trim(cs.branch), '') as branch
  from public.club_sessions cs, member m
  where cs.member_id = m.id
    and cs.phase in ('inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry')
  order by
    case cs.phase
      when 'inside_club' then 0
      when 'awaiting_exit_scan' then 1
      else 2
    end,
    cs.entered_at desc nulls last,
    cs.created_at desc
  limit 1
),
guests as (
  select
    ce.title,
    ce.branch as event_branch,
    ce.starts_at,
    ce.ends_at,
    coalesce(ce.approval_status, '(null)') as approval_status,
    coalesce(ce.status, '(null)') as event_status,
    eg.status as guest_status,
    eg.invite_id,
    eg.checked_in_at,
    (ce.ends_at is null or now() < ce.ends_at)
      and (
        ce.starts_at <= now()
        or (ce.starts_at at time zone 'Asia/Manila')::date
           = (now() at time zone 'Asia/Manila')::date
      ) as is_on_for_door,
    (select branch from session) is null
      or lower(trim(ce.branch)) = lower(trim((select branch from session)))
      as branch_matches
  from public.event_guests eg
  join public.club_events ce on ce.id = eg.event_id
  join member m on m.id = eg.member_id
)
select * from (
  -- ---------------------------------------------------------------- deployment
  select 10 as ord, 'DB: event_guests.last_checked_in_at (migration 035)' as check,
    case when exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'event_guests'
        and column_name = 'last_checked_in_at'
    ) then 'PASS — 035 applied' else 'FAIL — run migration 035' end as verdict
  union all
  select 11, 'DB: list_my_event_invites returns last_checked_in_at',
    case when position('last_checked_in_at' in coalesce((select invites_def from fn), '')) > 0
      then 'PASS' else 'FAIL — run migration 035' end
  union all
  select 12, 'DB: list_my_event_invites left joins event_invites',
    case when position('left join public.event_invites' in lower(coalesce((select invites_def from fn), ''))) > 0
      then 'PASS' else 'FAIL — guests with no invite row are hidden (migration 035)' end
  union all
  select 13, 'DB: get_active_event_for_member scopes by session branch (034)',
    case when position('event_matches_session_branch' in coalesce((select active_def from fn), '')) > 0
      then 'PASS — 034 applied' else 'FAIL — migrations 034/035 not applied' end
  union all
  select 14, 'DB: helper functions from migrations 028+ exist',
    coalesce((
      select string_agg(name || '=' ||
        case when exists (
          select 1 from pg_proc p
          where p.pronamespace = 'public'::regnamespace and p.proname = name
        ) then 'yes' else 'NO' end, ', ' order by name)
      from (values
        ('sync_club_event_runtime_statuses'),
        ('is_event_approved_for_ops'),
        ('is_event_on_for_door_checkin'),
        ('event_matches_session_branch')
      ) as t(name)
    ), 'none')
  -- -------------------------------------------------------------------- member
  union all
  select 20, 'Member: found for that email',
    coalesce((select id::text || '  role=' || coalesce(role, '(null)') from member),
             'FAIL — no profile with that email')
  union all
  select 21, 'Member: app reads event data for this role',
    case coalesce((select role from member), '')
      when 'member' then 'PASS — member'
      when '' then 'FAIL — member not found'
      else 'CHECK — role is not member; the app blanks all event state unless '
           || 'the email is a super admin (usesMemberSurface)'
    end
  union all
  select 22, 'Session: phase must be inside_club',
    coalesce((select 'phase=' || phase || '  branch=' || coalesce(branch, '(none)')
              from session), 'FAIL — no open club session')
  -- ------------------------------------------------------------- guest rows
  union all
  select 30, 'Guest rows for this member', coalesce((select count(*)::text from guests), '0')
  union all
  select
    31,
    'Event: ' || title,
    'guest_status=' || guest_status
      || '  invite_row=' || case when invite_id is null then 'MISSING' else 'yes' end
      || '  checked_in_at=' || coalesce(checked_in_at::text, 'never')
      || '  branch=' || coalesce(event_branch, '(none)')
      || '  window=' || coalesce(starts_at::text, '(none)') || ' → ' || coalesce(ends_at::text, 'open')
      || '  approval=' || approval_status || '/' || event_status
  from guests
  union all
  select
    32,
    'VERDICT: ' || title,
    case
      when guest_status <> 'checked_in' then 'FAIL — guest is ' || guest_status || ', not checked_in'
      when not is_on_for_door then 'FAIL — event is over or not on today'
      when not branch_matches then 'FAIL — event branch <> session branch'
      when (select phase from session) is distinct from 'inside_club'
        then 'FAIL — member is not inside_club'
      else 'PASS — the app should raise the welcome for this event'
    end
  from guests
) report
order by ord, check;
