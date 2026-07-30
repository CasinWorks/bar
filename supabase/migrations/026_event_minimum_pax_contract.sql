-- Persist minimum pax on hosted events and accept it in the RPC contract.

alter table public.club_events
  add column if not exists minimum_pax int;

drop trigger if exists trg_validate_club_event_request on public.club_events;

update public.club_events
set minimum_pax = 10
where minimum_pax is null;

alter table public.club_events
  alter column minimum_pax set default 10,
  alter column minimum_pax set not null;

alter table public.club_events drop constraint if exists club_events_minimum_pax_check;
alter table public.club_events
  add constraint club_events_minimum_pax_check
  check (minimum_pax >= 10);

create or replace function public.validate_club_event_request()
returns trigger
language plpgsql
as $$
declare
  v_host_name text;
begin
  if new.starts_at is null then
    raise exception 'Event start time required.';
  end if;

  if new.ends_at is null then
    raise exception 'Event end time required.';
  end if;

  if new.ends_at <= new.starts_at then
    raise exception 'Event end must be after start.';
  end if;

  if coalesce(new.requested_by, new.host_id) is not null
     and coalesce(new.approval_status, 'pending_review') in ('pending_review', 'needs_revision') then
    if new.starts_at < now() + interval '7 days' then
      raise exception 'Hosted event requests must be scheduled at least 7 days ahead.';
    end if;
  end if;

  if coalesce(new.minimum_pax, 10) < 10 then
    raise exception 'Hosted events require a minimum pax of 10 or more.';
  end if;

  if coalesce(new.wallet_seconds, 0) < 0 then
    raise exception 'Event wallet cannot be negative.';
  end if;

  if coalesce(new.wallet_low_threshold_seconds, 0) < 0 then
    raise exception 'Low-wallet threshold cannot be negative.';
  end if;

  if coalesce(new.host_name, '') = '' and new.host_id is not null then
    select coalesce(nullif(trim(p.name), ''), 'Host')
      into v_host_name
    from public.profiles p
    where p.id = new.host_id;
    new.host_name := coalesce(v_host_name, 'Host');
  end if;

  new.minimum_pax := coalesce(new.minimum_pax, 10);
  new.request_submitted_at := coalesce(new.request_submitted_at, now());
  return new;
end;
$$;

create trigger trg_validate_club_event_request
  before insert or update on public.club_events
  for each row
  execute function public.validate_club_event_request();

drop function if exists public.submit_event_request(
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  int,
  text,
  text,
  int,
  jsonb
);

create or replace function public.submit_event_request(
  p_title text,
  p_description text default null,
  p_branch text default null,
  p_event_type text default 'private_social',
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_capacity int default null,
  p_request_notes text default null,
  p_host_phone text default null,
  p_wallet_seconds int default 7200,
  p_invites jsonb default '[]'::jsonb,
  p_minimum_pax int default 10
)
returns public.club_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_event public.club_events;
  v_item jsonb;
  v_name text;
  v_email text;
  v_phone text;
  v_minimum_pax int := coalesce(p_minimum_pax, 10);
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select *
    into v_profile
  from public.profiles
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found.';
  end if;

  if nullif(trim(coalesce(p_title, '')), '') is null then
    raise exception 'Event title required.';
  end if;

  if p_starts_at is null or p_ends_at is null then
    raise exception 'Start and end times required.';
  end if;

  if p_starts_at < now() + interval '7 days' then
    raise exception 'Event requests must be at least 7 days ahead.';
  end if;

  if p_ends_at <= p_starts_at then
    raise exception 'Event end must be after start.';
  end if;

  if v_minimum_pax < 10 then
    raise exception 'Minimum pax must be at least 10.';
  end if;

  if coalesce(p_wallet_seconds, 0) < 3600 then
    raise exception 'Event wallet must start at 60 minutes or more.';
  end if;

  insert into public.club_events (
    title,
    description,
    branch,
    starts_at,
    ends_at,
    capacity,
    minimum_pax,
    vip_only,
    status,
    created_by,
    requested_by,
    host_id,
    host_name,
    host_email,
    host_phone,
    request_notes,
    event_type,
    approval_status,
    request_submitted_at,
    wallet_seconds,
    wallet_low_threshold_seconds,
    wallet_total_extended_seconds,
    wallet_consumed_seconds,
    wallet_last_extended_at,
    wallet_low_notified_at
  ) values (
    trim(p_title),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(nullif(trim(coalesce(p_branch, '')), ''), coalesce(v_profile.branch, 'Cubao Branch')),
    p_starts_at,
    p_ends_at,
    p_capacity,
    v_minimum_pax,
    false,
    'scheduled',
    auth.uid(),
    auth.uid(),
    auth.uid(),
    coalesce(nullif(trim(v_profile.name), ''), 'Host'),
    nullif(trim(coalesce(v_profile.email, '')), ''),
    coalesce(nullif(trim(coalesce(p_host_phone, '')), ''), nullif(trim(coalesce(v_profile.phone, '')), '')),
    nullif(trim(coalesce(p_request_notes, '')), ''),
    lower(trim(coalesce(p_event_type, 'private_social'))),
    'pending_review',
    now(),
    p_wallet_seconds,
    least(greatest(p_wallet_seconds / 4, 900), 3600),
    0,
    0,
    now(),
    null
  )
  returning * into v_event;

  insert into public.event_wallet_transactions (
    event_id,
    actor_id,
    kind,
    seconds_delta,
    balance_after_seconds,
    note
  ) values (
    v_event.id,
    auth.uid(),
    'seed',
    p_wallet_seconds,
    p_wallet_seconds,
    'Initial requested event wallet.'
  );

  if jsonb_typeof(coalesce(p_invites, '[]'::jsonb)) = 'array' then
    for v_item in
      select value from jsonb_array_elements(coalesce(p_invites, '[]'::jsonb))
    loop
      v_name := trim(coalesce(v_item ->> 'name', ''));
      v_email := lower(trim(coalesce(v_item ->> 'email', '')));
      v_phone := trim(coalesce(v_item ->> 'phone', ''));

      if v_name = '' then
        continue;
      end if;

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
        last_sent_at,
        notes
      ) values (
        v_event.id,
        v_name,
        nullif(v_email, ''),
        nullif(v_phone, ''),
        public.event_guest_identity_key(v_name, v_email, v_phone),
        public.generate_event_invite_code(),
        public.generate_event_invite_token(),
        'pending',
        auth.uid(),
        now(),
        nullif(trim(coalesce(v_item ->> 'notes', '')), '')
      )
      on conflict (event_id, guest_identity_key) do nothing;
    end loop;
  end if;

  return v_event;
end;
$$;

drop function if exists public.create_event_request(
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  int,
  text,
  text,
  int,
  jsonb
);

create or replace function public.create_event_request(
  p_title text,
  p_description text default null,
  p_branch text default null,
  p_event_type text default 'private_social',
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_capacity int default null,
  p_request_notes text default null,
  p_host_phone text default null,
  p_wallet_seconds int default 7200,
  p_invites jsonb default '[]'::jsonb,
  p_minimum_pax int default 10
)
returns public.club_events
language sql
security definer
set search_path = public
as $$
  select public.submit_event_request(
    p_title,
    p_description,
    p_branch,
    p_event_type,
    p_starts_at,
    p_ends_at,
    p_capacity,
    p_request_notes,
    p_host_phone,
    p_wallet_seconds,
    p_invites,
    p_minimum_pax
  );
$$;

create or replace function public.fetch_event_invite_by_code(p_code text)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'invite_id', ei.id,
    'event_id', ce.id,
    'guest_name', ei.guest_name,
    'guest_email', ei.guest_email,
    'guest_phone', ei.guest_phone,
    'status', ei.status,
    'invite_code', ei.invite_code,
    'accepted_at', ei.accepted_at,
    'title', ce.title,
    'description', ce.description,
    'branch', ce.branch,
    'starts_at', ce.starts_at,
    'ends_at', ce.ends_at,
    'event_type', ce.event_type,
    'approval_status', ce.approval_status,
    'minimum_pax', ce.minimum_pax,
    'host_id', ce.host_id,
    'host_name', coalesce(ce.host_name, 'Host')
  )
  from public.event_invites ei
  join public.club_events ce on ce.id = ei.event_id
  where ei.invite_code = upper(trim(coalesce(p_code, '')))
  limit 1;
$$;

create or replace function public.fetch_event_invite_by_token(p_token text)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'invite_id', ei.id,
    'event_id', ce.id,
    'guest_name', ei.guest_name,
    'guest_email', ei.guest_email,
    'guest_phone', ei.guest_phone,
    'status', ei.status,
    'invite_code', ei.invite_code,
    'accepted_at', ei.accepted_at,
    'title', ce.title,
    'description', ce.description,
    'branch', ce.branch,
    'starts_at', ce.starts_at,
    'ends_at', ce.ends_at,
    'event_type', ce.event_type,
    'approval_status', ce.approval_status,
    'minimum_pax', ce.minimum_pax,
    'host_id', ce.host_id,
    'host_name', coalesce(ce.host_name, 'Host')
  )
  from public.event_invites ei
  join public.club_events ce on ce.id = ei.event_id
  where ei.invite_token = lower(trim(coalesce(p_token, '')))
  limit 1;
$$;

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

  if v_event.approval_status <> 'approved' then
    raise exception 'Event is not approved yet.';
  end if;

  if v_event.ends_at is not null and now() > v_event.ends_at then
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
        'invite_id', ei.id,
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
        'checked_in_at', eg.checked_in_at
      )
      order by ce.starts_at asc
    ),
    '[]'::jsonb
  )
  from public.event_guests eg
  join public.event_invites ei on ei.id = eg.invite_id
  join public.club_events ce on ce.id = eg.event_id
  where eg.member_id = auth.uid();
$$;

create or replace function public.get_active_event_for_member(
  p_member_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
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
    where ce.approval_status = 'approved'
      and public.is_event_active(ce.starts_at, ce.ends_at)
      and eg.status in ('accepted', 'checked_in')
    order by ce.starts_at desc
    limit 1
  ) as row_data;
$$;

grant execute on function public.submit_event_request(text, text, text, text, timestamptz, timestamptz, int, text, text, int, jsonb, int) to authenticated;
grant execute on function public.create_event_request(text, text, text, text, timestamptz, timestamptz, int, text, text, int, jsonb, int) to authenticated;
