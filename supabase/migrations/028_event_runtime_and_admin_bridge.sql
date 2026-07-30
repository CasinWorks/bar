-- Event runtime bridge: align admin calendar events with mobile check-in/welcome,
-- auto-live approved events in-window, and keep guest_list_entries synced.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_event_active(
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
language sql
stable
as $$
  select p_starts_at is not null
    and p_starts_at <= now()
    and (
      p_ends_at is null
      or now() <= p_ends_at
    );
$$;

create or replace function public.is_event_approved_for_ops(
  p_approval_status text,
  p_status text
)
returns boolean
language sql
stable
as $$
  select coalesce(p_approval_status, 'pending_review') = 'approved'
      or coalesce(p_status, 'scheduled') = 'live';
$$;

create or replace function public.sync_club_event_runtime_statuses()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.club_events
  set status = 'live'
  where coalesce(approval_status, 'pending_review') = 'approved'
    and coalesce(status, 'scheduled') = 'scheduled'
    and public.is_event_active(starts_at, ends_at);

  update public.club_events
  set status = 'completed'
  where coalesce(status, 'scheduled') = 'live'
    and ends_at is not null
    and ends_at < now();
end;
$$;

-- Admin "live" and missing end times should satisfy mobile RPC expectations.
create or replace function public.normalize_club_event_contract()
returns trigger
language plpgsql
as $$
begin
  if new.host_id is null and new.created_by is not null then
    new.host_id := new.created_by;
  end if;

  if new.ends_at is null and new.starts_at is not null then
    new.ends_at := new.starts_at + interval '8 hours';
  end if;

  if coalesce(new.status, 'scheduled') = 'live'
     and coalesce(new.approval_status, 'pending_review') <> 'approved' then
    new.approval_status := 'approved';
    new.approved_at := coalesce(new.approved_at, now());
  end if;

  if coalesce(new.approval_status, 'pending_review') = 'approved'
     and coalesce(new.status, 'scheduled') = 'scheduled'
     and public.is_event_active(new.starts_at, new.ends_at) then
    new.status := 'live';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalize_club_event_contract on public.club_events;
create trigger trg_normalize_club_event_contract
  before insert or update on public.club_events
  for each row
  execute function public.normalize_club_event_contract();

-- Keep legacy admin guest list rows mirrored into event_invites / event_guests.
create or replace function public.sync_guest_list_entry_to_event_contract(p_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  gle public.guest_list_entries%rowtype;
  v_invite_id uuid;
  v_guest_status text;
  v_invite_status text;
begin
  select *
    into gle
  from public.guest_list_entries
  where id = p_entry_id;

  if not found then
    return;
  end if;

  v_guest_status := case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('revoked', 'denied') then 'revoked'
    else 'accepted'
  end;

  v_invite_status := case gle.status
    when 'checked_in' then 'checked_in'
    when 'registered' then 'accepted'
    when 'confirmed' then 'accepted'
    when 'denied' then 'revoked'
    when 'revoked' then 'revoked'
    when 'no_show' then 'expired'
    else 'pending'
  end;

  insert into public.event_invites (
    event_id,
    guest_name,
    guest_email,
    guest_phone,
    guest_identity_key,
    invite_code,
    invite_token,
    status,
    created_by,
    accepted_by,
    accepted_at,
    last_sent_at,
    notes,
    created_at,
    updated_at
  ) values (
    gle.event_id,
    gle.name,
    gle.email,
    gle.phone,
    public.event_guest_identity_key(gle.name, gle.email, gle.phone),
    upper(coalesce(nullif(trim(gle.invite_code), ''), public.generate_event_invite_code())),
    public.generate_event_invite_token(),
    v_invite_status,
    gle.added_by,
    gle.invite_claimed_by,
    coalesce(gle.accepted_at, gle.invite_claimed_at),
    coalesce(gle.invited_at, gle.created_at),
    gle.notes,
    gle.created_at,
    greatest(
      gle.created_at,
      coalesce(gle.accepted_at, gle.invite_claimed_at, gle.checked_in_at, gle.created_at)
    )
  )
  on conflict (event_id, guest_identity_key) do update
  set guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      status = excluded.status,
      accepted_by = excluded.accepted_by,
      accepted_at = excluded.accepted_at,
      notes = excluded.notes,
      updated_at = excluded.updated_at
  returning id into v_invite_id;

  if gle.member_id is null then
    return;
  end if;

  insert into public.event_guests (
    event_id,
    invite_id,
    member_id,
    guest_name,
    guest_email,
    guest_phone,
    status,
    accepted_at,
    checked_in_at,
    checked_in_by,
    club_session_id,
    created_at,
    updated_at
  ) values (
    gle.event_id,
    v_invite_id,
    gle.member_id,
    gle.name,
    gle.email,
    gle.phone,
    v_guest_status,
    coalesce(gle.accepted_at, gle.invite_claimed_at, gle.created_at),
    gle.checked_in_at,
    gle.checked_in_by,
    gle.check_in_session_id,
    gle.created_at,
    greatest(
      gle.created_at,
      coalesce(gle.checked_in_at, gle.accepted_at, gle.invite_claimed_at, gle.created_at)
    )
  )
  on conflict (event_id, member_id) do update
  set invite_id = excluded.invite_id,
      guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      status = excluded.status,
      accepted_at = excluded.accepted_at,
      checked_in_at = excluded.checked_in_at,
      checked_in_by = excluded.checked_in_by,
      club_session_id = excluded.club_session_id,
      updated_at = excluded.updated_at;
end;
$$;

create or replace function public.trg_sync_guest_list_entry_to_event_contract()
returns trigger
language plpgsql
as $$
begin
  perform public.sync_guest_list_entry_to_event_contract(new.id);
  return new;
end;
$$;

drop trigger if exists trg_sync_guest_list_entry_to_event_contract on public.guest_list_entries;
create trigger trg_sync_guest_list_entry_to_event_contract
  after insert or update on public.guest_list_entries
  for each row
  execute function public.trg_sync_guest_list_entry_to_event_contract();

-- ---------------------------------------------------------------------------
-- Backfill existing admin rows
-- ---------------------------------------------------------------------------

update public.club_events
set ends_at = starts_at + interval '8 hours'
where ends_at is null
  and starts_at is not null;

update public.club_events
set approval_status = 'approved',
    approved_at = coalesce(approved_at, now())
where coalesce(status, 'scheduled') = 'live'
  and coalesce(approval_status, 'pending_review') <> 'approved';

update public.club_events
set host_id = created_by
where host_id is null
  and created_by is not null;

select public.sync_club_event_runtime_statuses();

insert into public.event_invites (
  event_id,
  guest_name,
  guest_email,
  guest_phone,
  guest_identity_key,
  invite_code,
  invite_token,
  status,
  created_by,
  accepted_by,
  accepted_at,
  last_sent_at,
  notes,
  created_at,
  updated_at
)
select
  gle.event_id,
  gle.name,
  gle.email,
  gle.phone,
  public.event_guest_identity_key(gle.name, gle.email, gle.phone),
  upper(coalesce(nullif(trim(gle.invite_code), ''), public.generate_event_invite_code())),
  public.generate_event_invite_token(),
  case gle.status
    when 'checked_in' then 'checked_in'
    when 'registered' then 'accepted'
    when 'confirmed' then 'accepted'
    when 'denied' then 'revoked'
    when 'revoked' then 'revoked'
    when 'no_show' then 'expired'
    else 'pending'
  end,
  gle.added_by,
  gle.invite_claimed_by,
  coalesce(gle.accepted_at, gle.invite_claimed_at),
  coalesce(gle.invited_at, gle.created_at),
  gle.notes,
  gle.created_at,
  greatest(
    gle.created_at,
    coalesce(gle.accepted_at, gle.invite_claimed_at, gle.checked_in_at, gle.created_at)
  )
from public.guest_list_entries gle
on conflict (event_id, guest_identity_key) do nothing;

insert into public.event_guests (
  event_id,
  invite_id,
  member_id,
  guest_name,
  guest_email,
  guest_phone,
  status,
  accepted_at,
  checked_in_at,
  checked_in_by,
  club_session_id,
  created_at,
  updated_at
)
select
  gle.event_id,
  ei.id,
  gle.member_id,
  gle.name,
  gle.email,
  gle.phone,
  case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('revoked', 'denied') then 'revoked'
    else 'accepted'
  end,
  coalesce(gle.accepted_at, gle.invite_claimed_at, gle.created_at),
  gle.checked_in_at,
  gle.checked_in_by,
  gle.check_in_session_id,
  gle.created_at,
  greatest(
    gle.created_at,
    coalesce(gle.checked_in_at, gle.accepted_at, gle.invite_claimed_at, gle.created_at)
  )
from public.guest_list_entries gle
join public.event_invites ei
  on ei.event_id = gle.event_id
 and ei.guest_identity_key = public.event_guest_identity_key(gle.name, gle.email, gle.phone)
where gle.member_id is not null
on conflict (event_id, member_id) do update
set invite_id = excluded.invite_id,
    guest_name = excluded.guest_name,
    guest_email = excluded.guest_email,
    guest_phone = excluded.guest_phone,
    status = excluded.status,
    accepted_at = excluded.accepted_at,
    checked_in_at = excluded.checked_in_at,
    checked_in_by = excluded.checked_in_by,
    club_session_id = excluded.club_session_id,
    updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- Mobile-facing RPCs
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
begin
  perform public.sync_club_event_runtime_statuses();

  return (
    with target_member as (
      select coalesce(p_member_id, auth.uid()) as member_id
    )
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
      join public.event_invites ei on ei.id = eg.invite_id
      join public.club_events ce on ce.id = eg.event_id
      join target_member tm on tm.member_id = eg.member_id
      where public.is_event_approved_for_ops(ce.approval_status, ce.status)
        and public.is_event_active(ce.starts_at, ce.ends_at)
        and eg.status in ('accepted', 'checked_in')
      order by ce.starts_at desc
      limit 1
    ) as row_data
  );
end;
$$;

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

  select count(*)
    into v_match_count
  from public.event_guests eg
  join public.club_events ce on ce.id = eg.event_id
  where eg.member_id = p_member_id
    and public.is_event_approved_for_ops(ce.approval_status, ce.status)
    and public.is_event_active(ce.starts_at, ce.ends_at)
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
    and public.is_event_active(ce.starts_at, ce.ends_at)
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
      'event_guest_id', v_guest.id,
      'guest_name', v_guest.guest_name,
      'member_id', p_member_id,
      'session_id', p_session_id
    )
  );

  return jsonb_build_object(
    'event_id', v_event.id,
    'event_title', v_event.title,
    'event_guest_id', v_guest.id,
    'invite_id', v_guest.invite_id,
    'guest_name', v_guest.guest_name,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'checked_in_at', v_guest.checked_in_at,
    'club_session_id', v_guest.club_session_id
  );
end;
$$;

create or replace function public.list_event_host_notifications(
  p_unread_only boolean default true,
  p_limit int default 20
)
returns table (
  id uuid,
  sender_id uuid,
  recipient_id uuid,
  kind text,
  message text,
  created_at timestamptz,
  read_at timestamptz,
  event_id uuid,
  event_title text,
  event_guest_id uuid,
  guest_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.id,
    n.sender_id,
    n.recipient_id,
    n.kind,
    n.message,
    n.created_at,
    n.read_at,
    nullif(n.metadata ->> 'event_id', '')::uuid as event_id,
    coalesce(n.metadata ->> 'event_title', 'Event') as event_title,
    nullif(n.metadata ->> 'event_guest_id', '')::uuid as event_guest_id,
    coalesce(n.metadata ->> 'guest_name', 'A guest') as guest_name
  from public.member_notifications n
  where n.recipient_id = auth.uid()
    and n.kind in ('event_guest_checkin', 'event_wallet_low')
    and (not p_unread_only or n.read_at is null)
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;

grant execute on function public.sync_club_event_runtime_statuses() to authenticated;
grant execute on function public.list_event_host_notifications(boolean, int) to authenticated;
