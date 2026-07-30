-- The guest welcome page must fire on every door scan, not once per event.
-- `checked_in_at` is coalesced so it keeps the guest's real arrival time, which
-- left the client with no way to tell a fresh scan from a replayed row. A
-- separate `last_checked_in_at` stamp moves on every scan and is what the guest
-- app keys its welcome on.

alter table public.event_guests
  add column if not exists last_checked_in_at timestamptz;

update public.event_guests
set last_checked_in_at = checked_in_at
where last_checked_in_at is null
  and checked_in_at is not null;

-- ---------------------------------------------------------------------------
-- Guest: active attendance for welcome / wallet (now carries the scan stamp)
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
        coalesce(eg.last_checked_in_at, eg.checked_in_at) as last_checked_in_at,
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
-- Staff: door scan event check-in (stamps every scan)
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
      last_checked_in_at = now(),
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
    'last_checked_in_at', v_guest.last_checked_in_at,
    'club_session_id', v_guest.club_session_id,
    'session_branch', v_branch
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Guest: invite list also carries the scan stamp
-- ---------------------------------------------------------------------------
-- `get_active_event_for_member` filters on approval, the door window and a
-- branch lookup against the member's club session, so it can answer null while
-- the guest is demonstrably checked in. The invite list is the client's
-- fallback for raising the welcome, so it has to expose the same scan stamp or
-- the two sources disagree about which welcome was already delivered.
--
-- The join to event_invites also becomes a left join: admin-added guests can
-- have an event_guests row with no invite row, and the inner join hid those
-- guests from their own Events & Calendar and from the welcome.

create or replace function public.list_my_event_invites()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'invite_id', coalesce(ei.id, eg.id),
        'event_guest_id', eg.id,
        'event_id', ce.id,
        'title', ce.title,
        'branch', ce.branch,
        'starts_at', ce.starts_at,
        'ends_at', ce.ends_at,
        'event_type', ce.event_type,
        'approval_status', ce.approval_status,
        'minimum_pax', ce.minimum_pax,
        'host_id', ce.host_id,
        'host_name', coalesce(ce.host_name, 'Host'),
        'guest_name', eg.guest_name,
        'invite_code', ei.invite_code,
        'status', eg.status,
        'accepted_at', eg.accepted_at,
        'checked_in_at', eg.checked_in_at,
        'last_checked_in_at', coalesce(eg.last_checked_in_at, eg.checked_in_at)
      )
      order by ce.starts_at asc
    ),
    '[]'::jsonb
  )
  from public.event_guests eg
  left join public.event_invites ei on ei.id = eg.invite_id
  join public.club_events ce on ce.id = eg.event_id
  where eg.member_id = auth.uid();
$$;

grant execute on function public.get_active_event_for_member(uuid) to authenticated;
grant execute on function public.staff_check_in_event_guest(uuid, uuid) to authenticated;
grant execute on function public.list_my_event_invites() to authenticated;
