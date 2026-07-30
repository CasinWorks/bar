-- Explicit event start/end window as lifecycle source of truth.
-- Half-open active window: starts_at <= now() < ends_at
-- Persist status via idempotent sync on reads; do not require a cron job.

-- ---------------------------------------------------------------------------
-- Window + derived status helpers
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
    and p_ends_at is not null
    and p_starts_at <= now()
    and now() < p_ends_at;
$$;

create or replace function public.event_runtime_status(
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_status text default 'scheduled'
)
returns text
language sql
stable
as $$
  select case
    when coalesce(p_status, 'scheduled') = 'cancelled' then 'cancelled'
    when p_ends_at is not null and now() >= p_ends_at then 'completed'
    when p_starts_at is not null
         and p_starts_at <= now()
         and (p_ends_at is null or now() < p_ends_at) then 'live'
    else 'scheduled'
  end;
$$;

create or replace function public.sync_club_event_runtime_statuses()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Past end → completed (scheduled or live; never touch cancelled).
  update public.club_events
  set status = 'completed'
  where coalesce(status, 'scheduled') <> 'cancelled'
    and ends_at is not null
    and now() >= ends_at
    and coalesce(status, 'scheduled') <> 'completed';

  -- Approved + in window → live.
  update public.club_events
  set status = 'live'
  where coalesce(approval_status, 'pending_review') = 'approved'
    and coalesce(status, 'scheduled') = 'scheduled'
    and public.is_event_active(starts_at, ends_at);

  -- Approved but still before start → scheduled (handles edited starts_at).
  update public.club_events
  set status = 'scheduled'
  where coalesce(approval_status, 'pending_review') = 'approved'
    and coalesce(status, 'scheduled') = 'live'
    and starts_at is not null
    and starts_at > now()
    and (ends_at is null or ends_at > now());
end;
$$;

-- Keep row status aligned on write; still prefer timestamps on ops reads.
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

  if new.starts_at is not null
     and new.ends_at is not null
     and new.ends_at <= new.starts_at then
    raise exception 'Event end must be after start.';
  end if;

  if coalesce(new.status, 'scheduled') = 'live'
     and coalesce(new.approval_status, 'pending_review') <> 'approved' then
    new.approval_status := 'approved';
    new.approved_at := coalesce(new.approved_at, now());
  end if;

  -- Derive runtime status from the window unless cancelled.
  if coalesce(new.status, 'scheduled') <> 'cancelled' then
    new.status := public.event_runtime_status(
      new.starts_at,
      new.ends_at,
      new.status
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalize_club_event_contract on public.club_events;
create trigger trg_normalize_club_event_contract
  before insert or update on public.club_events
  for each row
  execute function public.normalize_club_event_contract();

-- Backfill + sync persisted statuses from timestamps.
select public.sync_club_event_runtime_statuses();

-- ---------------------------------------------------------------------------
-- Invite accept: sync lifecycle, reject closed/cancelled/cancelled events
-- ---------------------------------------------------------------------------

create or replace function public.accept_event_invite(
  p_code text,
  p_accept_via text default 'code'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_invite public.event_invites%rowtype;
  v_event public.club_events%rowtype;
  v_guest public.event_guests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required.';
  end if;

  perform public.sync_club_event_runtime_statuses();

  select *
    into v_profile
  from public.profiles
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found.';
  end if;

  select *
    into v_invite
  from public.event_invites
  where invite_code = upper(trim(coalesce(p_code, '')))
  for update;

  if not found then
    raise exception 'Invite code not found.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = v_invite.event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if coalesce(v_event.status, 'scheduled') = 'cancelled' then
    raise exception 'This event was cancelled.';
  end if;

  if v_event.approval_status <> 'approved' then
    raise exception 'Event is not approved yet.';
  end if;

  if v_event.ends_at is null
     or now() >= v_event.ends_at
     or coalesce(v_event.status, 'scheduled') = 'completed' then
    raise exception 'This invite has expired.';
  end if;

  if v_invite.status in ('revoked', 'expired') then
    raise exception 'This invite is no longer valid.';
  end if;

  if nullif(lower(trim(coalesce(v_invite.guest_email, ''))), '') is not null
     and lower(trim(coalesce(v_profile.email, ''))) <> lower(trim(coalesce(v_invite.guest_email, ''))) then
    raise exception 'Invite email does not match this account.';
  end if;

  if v_invite.accepted_by is not null and v_invite.accepted_by <> auth.uid() then
    raise exception 'Invite already claimed.';
  end if;

  if exists (
    select 1
    from public.event_guests eg
    where eg.event_id = v_invite.event_id
      and eg.member_id = auth.uid()
      and eg.invite_id <> v_invite.id
  ) then
    raise exception 'You already have an invite for this event.';
  end if;

  insert into public.event_guests (
    event_id,
    invite_id,
    member_id,
    guest_name,
    guest_email,
    guest_phone,
    status,
    accepted_at
  ) values (
    v_invite.event_id,
    v_invite.id,
    auth.uid(),
    v_invite.guest_name,
    v_invite.guest_email,
    v_invite.guest_phone,
    'accepted',
    now()
  )
  on conflict (event_id, member_id) do update
    set invite_id = excluded.invite_id,
        guest_name = excluded.guest_name,
        guest_email = excluded.guest_email,
        guest_phone = excluded.guest_phone,
        status = case
          when public.event_guests.status = 'checked_in' then 'checked_in'
          else 'accepted'
        end,
        accepted_at = excluded.accepted_at
  returning * into v_guest;

  update public.event_invites
  set accepted_by = auth.uid(),
      accepted_at = now(),
      status = case
        when status = 'checked_in' then status
        else 'accepted'
      end
  where id = v_invite.id
  returning * into v_invite;

  return jsonb_build_object(
    'invite_id', v_invite.id,
    'event_guest_id', v_guest.id,
    'event_id', v_event.id,
    'title', v_event.title,
    'branch', v_event.branch,
    'starts_at', v_event.starts_at,
    'ends_at', v_event.ends_at,
    'event_type', v_event.event_type,
    'minimum_pax', v_event.minimum_pax,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'guest_name', v_guest.guest_name,
    'status', v_guest.status,
    'accepted_at', v_guest.accepted_at,
    'accepted_via', case
      when lower(trim(coalesce(p_accept_via, 'code'))) = 'token' then 'token'
      else 'code'
    end
  );
end;
$$;

grant execute on function public.event_runtime_status(timestamptz, timestamptz, text) to authenticated;
grant execute on function public.sync_club_event_runtime_statuses() to authenticated;
