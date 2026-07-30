-- Door event check-in: scope to the guest's venue branch and "on today".
-- Primary path: staff scans member entry QR → staff_check_in_event_guest →
-- guest get_active_event_for_member sees checked_in → welcome overlay.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.normalize_branch_label(p_branch text)
returns text
language sql
immutable
as $$
  select lower(trim(coalesce(p_branch, '')));
$$;

-- Session/staff branch wins when present; empty session branch skips filtering
-- so legacy rows without a branch label still check in.
create or replace function public.event_matches_session_branch(
  p_event_branch text,
  p_session_branch text
)
returns boolean
language sql
immutable
as $$
  select
    public.normalize_branch_label(p_session_branch) = ''
    or public.normalize_branch_label(p_event_branch)
         = public.normalize_branch_label(p_session_branch);
$$;

-- Eligible for door event check-in when the event is live, or starts today
-- (Asia/Manila) and has not ended — matches "event going on today".
create or replace function public.is_event_on_for_door_checkin(
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
language sql
stable
as $$
  select p_starts_at is not null
    and (p_ends_at is null or now() < p_ends_at)
    and (
      public.is_event_active(p_starts_at, p_ends_at)
      or (timezone('Asia/Manila', p_starts_at))::date
           = (timezone('Asia/Manila', now()))::date
    );
$$;

-- ---------------------------------------------------------------------------
-- Guest: active attendance for welcome / wallet (branch-aware)
-- ---------------------------------------------------------------------------

create or replace function public.get_active_event_for_member(
  p_member_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_member_id uuid;
  v_session_branch text;
begin
  perform public.sync_club_event_runtime_statuses();

  v_member_id := coalesce(p_member_id, auth.uid());

  select nullif(trim(cs.branch), '')
    into v_session_branch
  from public.club_sessions cs
  where cs.member_id = v_member_id
    and cs.phase in ('inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry')
  order by
    case cs.phase
      when 'inside_club' then 0
      when 'awaiting_exit_scan' then 1
      else 2
    end,
    cs.entered_at desc nulls last,
    cs.created_at desc
  limit 1;

  return (
    select to_jsonb(row_data)
    from (
      select
        ce.id as event_id,
        ce.title,
        ce.branch,
        ce.starts_at,
        ce.ends_at,
        ce.event_type,
        ce.minimum_pax,
        ce.host_id,
        coalesce(ce.host_name, 'Host') as host_name,
        ce.wallet_seconds,
        ce.wallet_low_threshold_seconds,
        ei.id as invite_id,
        ei.invite_code,
        eg.id as event_guest_id,
        eg.guest_name,
        eg.status,
        eg.checked_in_at,
        eg.accepted_at
      from public.event_guests eg
      left join public.event_invites ei on ei.id = eg.invite_id
      join public.club_events ce on ce.id = eg.event_id
      where eg.member_id = v_member_id
        and public.is_event_approved_for_ops(ce.approval_status, ce.status)
        and public.is_event_on_for_door_checkin(ce.starts_at, ce.ends_at)
        and public.event_matches_session_branch(ce.branch, v_session_branch)
        and eg.status in ('accepted', 'checked_in')
      order by
        case when eg.status = 'checked_in' then 0 else 1 end,
        ce.starts_at desc
      limit 1
    ) as row_data
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff: door scan event check-in (branch-aware)
-- ---------------------------------------------------------------------------

create or replace function public.staff_check_in_event_guest(
  p_member_id uuid,
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.club_sessions%rowtype;
  v_match_count int;
  v_guest public.event_guests%rowtype;
  v_event public.club_events%rowtype;
  v_event_id uuid;
  v_branch text;
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff access required.';
  end if;

  perform public.sync_club_event_runtime_statuses();

  select *
    into v_session
  from public.club_sessions
  where id = p_session_id
    and member_id = p_member_id;

  if not found then
    raise exception 'Club session not found for this member.';
  end if;

  if v_session.entered_at is null then
    raise exception 'Member has not been venue checked in yet.';
  end if;

  -- Prefer the guest session branch (venue they paid for), then staff profile.
  v_branch := nullif(trim(v_session.branch), '');
  if v_branch is null then
    select nullif(trim(p.branch), '')
      into v_branch
    from public.profiles p
    where p.id = auth.uid();
  end if;

  select count(*)
    into v_match_count
  from public.event_guests eg
  join public.club_events ce on ce.id = eg.event_id
  where eg.member_id = p_member_id
    and public.is_event_approved_for_ops(ce.approval_status, ce.status)
    and public.is_event_on_for_door_checkin(ce.starts_at, ce.ends_at)
    and public.event_matches_session_branch(ce.branch, v_branch)
    and eg.status in ('accepted', 'checked_in');

  if v_match_count = 0 then
    return null;
  end if;

  if v_match_count > 1 then
    raise exception 'Multiple active event guests found. Resolve manually in admin.';
  end if;

  select eg.event_id
    into v_event_id
  from public.event_guests eg
  join public.club_events ce on ce.id = eg.event_id
  where eg.member_id = p_member_id
    and public.is_event_approved_for_ops(ce.approval_status, ce.status)
    and public.is_event_on_for_door_checkin(ce.starts_at, ce.ends_at)
    and public.event_matches_session_branch(ce.branch, v_branch)
    and eg.status in ('accepted', 'checked_in')
  limit 1
  for update of eg, ce;

  select *
    into v_guest
  from public.event_guests
  where event_id = v_event_id
    and member_id = p_member_id
  for update;

  select *
    into v_event
  from public.club_events
  where id = v_event_id;

  update public.event_guests
  set status = 'checked_in',
      checked_in_at = coalesce(checked_in_at, now()),
      checked_in_by = auth.uid(),
      club_session_id = p_session_id
  where id = v_guest.id
  returning * into v_guest;

  update public.event_invites
  set status = 'checked_in'
  where id = v_guest.invite_id;

  insert into public.member_notifications (
    sender_id,
    recipient_id,
    kind,
    message,
    metadata
  ) values (
    p_member_id,
    v_event.host_id,
    'event_guest_checkin',
    coalesce(v_guest.guest_name, 'A guest') || ' checked in for ' || v_event.title || '.',
    jsonb_build_object(
      'event_id', v_event.id,
      'event_title', v_event.title,
      'event_branch', v_event.branch,
      'event_guest_id', v_guest.id,
      'guest_name', v_guest.guest_name,
      'member_id', p_member_id,
      'session_id', p_session_id,
      'session_branch', v_branch
    )
  );

  return jsonb_build_object(
    'event_id', v_event.id,
    'event_title', v_event.title,
    'event_branch', v_event.branch,
    'event_guest_id', v_guest.id,
    'invite_id', v_guest.invite_id,
    'guest_name', v_guest.guest_name,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'checked_in_at', v_guest.checked_in_at,
    'club_session_id', v_guest.club_session_id,
    'session_branch', v_branch
  );
end;
$$;

grant execute on function public.get_active_event_for_member(uuid) to authenticated;
grant execute on function public.staff_check_in_event_guest(uuid, uuid) to authenticated;
