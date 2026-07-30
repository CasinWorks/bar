-- Hosted event MVP: approval workflow, unique invites, attendance, and event wallet.

alter table public.club_events
  add column if not exists event_type text,
  add column if not exists approval_status text not null default 'pending_review',
  add column if not exists requested_by uuid references public.profiles(id),
  add column if not exists host_id uuid references public.profiles(id),
  add column if not exists host_name text,
  add column if not exists host_email text,
  add column if not exists host_phone text,
  add column if not exists request_notes text,
  add column if not exists admin_review_notes text,
  add column if not exists approved_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists wallet_seconds int not null default 0,
  add column if not exists wallet_low_threshold_seconds int not null default 1800,
  add column if not exists wallet_last_extended_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

update public.club_events
set event_type = coalesce(event_type, 'private_social')
where event_type is null;

alter table public.club_events drop constraint if exists club_events_event_type_check;
alter table public.club_events
  add constraint club_events_event_type_check
  check (
    event_type in (
      'birthday',
      'listening_party',
      'brand_party',
      'album_launch',
      'after_party',
      'private_social'
    )
  );

alter table public.club_events drop constraint if exists club_events_approval_status_check;
alter table public.club_events
  add constraint club_events_approval_status_check
  check (approval_status in ('pending_review', 'approved', 'rejected', 'needs_revision'));

alter table public.club_events drop constraint if exists club_events_wallet_seconds_check;
alter table public.club_events
  add constraint club_events_wallet_seconds_check check (wallet_seconds >= 0);

alter table public.club_events drop constraint if exists club_events_wallet_low_threshold_seconds_check;
alter table public.club_events
  add constraint club_events_wallet_low_threshold_seconds_check
  check (wallet_low_threshold_seconds >= 0);

create index if not exists club_events_host_id_idx on public.club_events (host_id);
create index if not exists club_events_requested_by_idx on public.club_events (requested_by);
create index if not exists club_events_approval_status_idx
  on public.club_events (approval_status, starts_at desc);

create or replace function public.touch_club_events_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_club_events_updated_at on public.club_events;
create trigger trg_club_events_updated_at
  before update on public.club_events
  for each row
  execute function public.touch_club_events_updated_at();

alter table public.guest_list_entries
  add column if not exists invite_code text,
  add column if not exists invited_at timestamptz not null default now(),
  add column if not exists invite_claimed_at timestamptz,
  add column if not exists invite_claimed_by uuid references public.profiles(id),
  add column if not exists accepted_at timestamptz,
  add column if not exists accepted_via text,
  add column if not exists checked_in_at timestamptz,
  add column if not exists checked_in_by uuid references public.profiles(id),
  add column if not exists check_in_session_id uuid references public.club_sessions(id),
  add column if not exists last_notification_at timestamptz;

update public.guest_list_entries
set plus_ones = 0
where plus_ones <> 0;

alter table public.guest_list_entries drop constraint if exists guest_list_entries_status_check;
alter table public.guest_list_entries
  add constraint guest_list_entries_status_check
  check (
    status in (
      'invited',
      'confirmed',
      'registered',
      'checked_in',
      'no_show',
      'denied',
      'revoked'
    )
  );

alter table public.guest_list_entries drop constraint if exists guest_list_entries_accepted_via_check;
alter table public.guest_list_entries
  add constraint guest_list_entries_accepted_via_check
  check (accepted_via is null or accepted_via in ('code', 'link'));

create unique index if not exists guest_list_entries_invite_code_idx
  on public.guest_list_entries (invite_code)
  where invite_code is not null;

create unique index if not exists guest_list_entries_event_member_idx
  on public.guest_list_entries (event_id, member_id)
  where member_id is not null;

create index if not exists guest_list_entries_member_idx
  on public.guest_list_entries (member_id, status);

create index if not exists guest_list_entries_checked_in_idx
  on public.guest_list_entries (checked_in_at desc)
  where checked_in_at is not null;

drop policy if exists "club_events_member_select" on public.club_events;
create policy "club_events_member_select"
  on public.club_events for select
  using (
    approval_status = 'approved'
    or requested_by = auth.uid()
    or host_id = auth.uid()
    or public.is_admin_or_hr()
  );

drop policy if exists "guest_list_host_or_member_select" on public.guest_list_entries;
create policy "guest_list_host_or_member_select"
  on public.guest_list_entries for select
  using (
    member_id = auth.uid()
    or lower(coalesce(email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or exists (
      select 1
      from public.club_events ce
      where ce.id = event_id
        and (
          ce.host_id = auth.uid()
          or ce.requested_by = auth.uid()
          or public.is_admin_or_hr()
        )
    )
  );

alter publication supabase_realtime add table public.club_events;
alter publication supabase_realtime add table public.guest_list_entries;

create or replace function public.generate_event_invite_code()
returns text
language plpgsql
as $$
begin
  return 'EVT-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
end;
$$;

create or replace function public.fetch_event_invite_by_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := upper(trim(coalesce(p_code, '')));
  v_invite record;
begin
  if v_norm = '' then
    raise exception 'Invite code required.';
  end if;

  select
    gle.id,
    gle.name,
    gle.email,
    gle.phone,
    gle.status,
    gle.member_id,
    gle.accepted_at,
    gle.checked_in_at,
    ce.id as event_id,
    ce.title,
    ce.description,
    ce.branch,
    ce.starts_at,
    ce.ends_at,
    ce.event_type,
    ce.approval_status,
    ce.host_id,
    ce.host_name
  into v_invite
  from public.guest_list_entries gle
  join public.club_events ce on ce.id = gle.event_id
  where gle.invite_code = v_norm
  limit 1;

  if not found then
    raise exception 'Invite not found.';
  end if;

  return jsonb_build_object(
    'invite_id', v_invite.id,
    'guest_name', v_invite.name,
    'guest_email', v_invite.email,
    'guest_phone', v_invite.phone,
    'status', v_invite.status,
    'member_id', v_invite.member_id,
    'accepted_at', v_invite.accepted_at,
    'checked_in_at', v_invite.checked_in_at,
    'event_id', v_invite.event_id,
    'title', v_invite.title,
    'description', v_invite.description,
    'branch', v_invite.branch,
    'starts_at', v_invite.starts_at,
    'ends_at', v_invite.ends_at,
    'event_type', v_invite.event_type,
    'approval_status', v_invite.approval_status,
    'host_id', v_invite.host_id,
    'host_name', coalesce(v_invite.host_name, 'Host')
  );
end;
$$;

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
  p_invites jsonb default '[]'::jsonb
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
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_profile
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
    wallet_seconds,
    wallet_low_threshold_seconds
  ) values (
    trim(p_title),
    nullif(trim(coalesce(p_description, '')), ''),
    coalesce(nullif(trim(coalesce(p_branch, '')), ''), coalesce(v_profile.branch, 'Cubao Branch')),
    p_starts_at,
    p_ends_at,
    p_capacity,
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
    p_wallet_seconds,
    least(greatest(p_wallet_seconds / 4, 900), 3600)
  )
  returning * into v_event;

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

      insert into public.guest_list_entries (
        event_id,
        name,
        email,
        phone,
        plus_ones,
        status,
        added_by,
        invite_code
      ) values (
        v_event.id,
        v_name,
        nullif(v_email, ''),
        nullif(v_phone, ''),
        0,
        'invited',
        auth.uid(),
        public.generate_event_invite_code()
      );
    end loop;
  end if;

  return v_event;
end;
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
  v_norm text := upper(trim(coalesce(p_code, '')));
  v_profile public.profiles%rowtype;
  v_invite public.guest_list_entries%rowtype;
  v_event public.club_events%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required.';
  end if;
  if v_norm = '' then
    raise exception 'Invite code required.';
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if not found then
    raise exception 'Profile not found.';
  end if;

  select * into v_invite
  from public.guest_list_entries
  where invite_code = v_norm
  for update;

  if not found then
    raise exception 'Invite code not found.';
  end if;

  select * into v_event
  from public.club_events
  where id = v_invite.event_id;

  if v_event.approval_status <> 'approved' then
    raise exception 'Event is not approved yet.';
  end if;
  if v_event.ends_at is not null and now() > v_event.ends_at then
    raise exception 'This invite has expired.';
  end if;
  if lower(coalesce(v_invite.email, '')) <> ''
     and lower(coalesce(v_invite.email, '')) <> lower(coalesce(v_profile.email, '')) then
    raise exception 'Invite email does not match this account.';
  end if;
  if v_invite.member_id is not null and v_invite.member_id <> auth.uid() then
    raise exception 'Invite already claimed.';
  end if;

  if exists (
    select 1
    from public.guest_list_entries gle
    where gle.event_id = v_invite.event_id
      and gle.member_id = auth.uid()
      and gle.id <> v_invite.id
  ) then
    raise exception 'You already have an invite for this event.';
  end if;

  update public.guest_list_entries
  set
    member_id = auth.uid(),
    invite_claimed_by = auth.uid(),
    invite_claimed_at = now(),
    accepted_at = now(),
    accepted_via = case
      when lower(coalesce(p_accept_via, 'code')) = 'link' then 'link'
      else 'code'
    end,
    status = case
      when status = 'checked_in' then status
      else 'registered'
    end
  where id = v_invite.id
  returning * into v_invite;

  return jsonb_build_object(
    'invite_id', v_invite.id,
    'event_id', v_event.id,
    'title', v_event.title,
    'branch', v_event.branch,
    'starts_at', v_event.starts_at,
    'ends_at', v_event.ends_at,
    'event_type', v_event.event_type,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'guest_name', v_invite.name,
    'status', v_invite.status,
    'accepted_at', v_invite.accepted_at
  );
end;
$$;

create or replace function public.list_my_hosted_events()
returns setof public.club_events
language sql
security definer
set search_path = public
stable
as $$
  select ce.*
  from public.club_events ce
  where ce.host_id = auth.uid() or ce.requested_by = auth.uid()
  order by ce.starts_at desc;
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
        'invite_id', gle.id,
        'event_id', ce.id,
        'title', ce.title,
        'branch', ce.branch,
        'starts_at', ce.starts_at,
        'ends_at', ce.ends_at,
        'event_type', ce.event_type,
        'approval_status', ce.approval_status,
        'host_id', ce.host_id,
        'host_name', coalesce(ce.host_name, 'Host'),
        'guest_name', gle.name,
        'status', gle.status,
        'invite_code', gle.invite_code,
        'accepted_at', gle.accepted_at,
        'checked_in_at', gle.checked_in_at
      )
      order by ce.starts_at asc
    ),
    '[]'::jsonb
  )
  from public.guest_list_entries gle
  join public.club_events ce on ce.id = gle.event_id
  where gle.member_id = auth.uid()
     or lower(coalesce(gle.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''));
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
      ce.host_id,
      coalesce(ce.host_name, 'Host') as host_name,
      ce.wallet_seconds,
      ce.wallet_low_threshold_seconds,
      gle.id as invite_id,
      gle.name as guest_name,
      gle.status,
      gle.checked_in_at,
      gle.accepted_at
    from public.guest_list_entries gle
    join public.club_events ce on ce.id = gle.event_id
    join target_member tm on tm.member_id = gle.member_id
    where ce.approval_status = 'approved'
      and ce.starts_at <= now()
      and now() <= coalesce(ce.ends_at, ce.starts_at + interval '8 hours')
      and gle.status in ('registered', 'confirmed', 'checked_in')
    order by ce.starts_at desc
    limit 1
  ) as row_data;
$$;

create or replace function public.extend_event_wallet(
  p_event_id uuid,
  p_minutes int
)
returns public.club_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events;
  v_add_seconds int;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if p_minutes < 15 then
    raise exception 'Minimum extension is 15 minutes.';
  end if;

  select * into v_event
  from public.club_events
  where id = p_event_id
    and host_id = auth.uid()
  for update;

  if not found then
    raise exception 'Hosted event not found.';
  end if;

  v_add_seconds := p_minutes * 60;

  update public.club_events
  set wallet_seconds = wallet_seconds + v_add_seconds,
      wallet_last_extended_at = now()
  where id = p_event_id
  returning * into v_event;

  return v_event;
end;
$$;

create or replace function public.consume_event_wallet_for_drink(
  p_event_id uuid,
  p_seconds int,
  p_order_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events;
  v_guest public.guest_list_entries;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if p_seconds <= 0 then
    raise exception 'Invalid spend amount.';
  end if;

  select * into v_guest
  from public.guest_list_entries
  where event_id = p_event_id
    and member_id = auth.uid()
    and status = 'checked_in'
  for update;

  if not found then
    raise exception 'You are not checked in for this event.';
  end if;

  select * into v_event
  from public.club_events
  where id = p_event_id
    and approval_status = 'approved'
    and starts_at <= now()
    and now() <= coalesce(ends_at, starts_at + interval '8 hours')
  for update;

  if not found then
    raise exception 'Event is not active.';
  end if;
  if v_event.wallet_seconds < p_seconds then
    raise exception 'Event wallet needs more time.';
  end if;

  update public.club_events
  set wallet_seconds = wallet_seconds - p_seconds
  where id = p_event_id
  returning * into v_event;

  if v_event.wallet_seconds <= v_event.wallet_low_threshold_seconds then
    insert into public.member_notifications (
      sender_id,
      recipient_id,
      kind,
      message,
      metadata
    ) values (
      auth.uid(),
      v_event.host_id,
      'event_wallet_low',
      coalesce(v_guest.name, 'A guest') || ' used event time for a drink. Event wallet is running low.',
      jsonb_build_object(
        'event_id', v_event.id,
        'event_title', v_event.title,
        'remaining_seconds', v_event.wallet_seconds,
        'order_id', p_order_id
      )
    );
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'wallet_seconds', v_event.wallet_seconds,
    'wallet_low_threshold_seconds', v_event.wallet_low_threshold_seconds
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
  v_staff_role text;
  v_guest public.guest_list_entries;
  v_event public.club_events;
  v_event_id uuid;
begin
  select role into v_staff_role
  from public.profiles
  where id = auth.uid();

  if v_staff_role <> 'staff' and v_staff_role <> 'admin' then
    raise exception 'Staff access required.';
  end if;

  select gle.event_id
  into v_event_id
  from public.guest_list_entries gle
  join public.club_events ce on ce.id = gle.event_id
  where gle.member_id = p_member_id
    and ce.approval_status = 'approved'
    and ce.starts_at <= now()
    and now() <= coalesce(ce.ends_at, ce.starts_at + interval '8 hours')
    and gle.status in ('registered', 'confirmed', 'checked_in')
  order by ce.starts_at desc
  limit 1
  for update of gle, ce;

  if not found then
    return null;
  end if;

  select *
  into v_guest
  from public.guest_list_entries
  where event_id = v_event_id
    and member_id = p_member_id
  order by created_at desc
  limit 1
  for update;

  select *
  into v_event
  from public.club_events
  where id = v_event_id;

  update public.guest_list_entries
  set
    status = 'checked_in',
    checked_in_at = coalesce(checked_in_at, now()),
    checked_in_by = auth.uid(),
    check_in_session_id = p_session_id,
    last_notification_at = now()
  where id = v_guest.id
  returning * into v_guest;

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
    coalesce(v_guest.name, 'A guest') || ' checked in for ' || v_event.title || '.',
    jsonb_build_object(
      'event_id', v_event.id,
      'event_title', v_event.title,
      'guest_entry_id', v_guest.id,
      'guest_name', v_guest.name,
      'member_id', p_member_id,
      'session_id', p_session_id
    )
  );

  return jsonb_build_object(
    'event_id', v_event.id,
    'event_title', v_event.title,
    'guest_entry_id', v_guest.id,
    'guest_name', v_guest.name,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'checked_in_at', v_guest.checked_in_at
  );
end;
$$;

grant execute on function public.fetch_event_invite_by_code(text) to anon, authenticated;
grant execute on function public.create_event_request(text, text, text, text, timestamptz, timestamptz, int, text, text, int, jsonb) to authenticated;
grant execute on function public.accept_event_invite(text, text) to authenticated;
grant execute on function public.list_my_hosted_events() to authenticated;
grant execute on function public.list_my_event_invites() to authenticated;
grant execute on function public.get_active_event_for_member(uuid) to authenticated;
grant execute on function public.extend_event_wallet(uuid, int) to authenticated;
grant execute on function public.consume_event_wallet_for_drink(uuid, int, uuid) to authenticated;
grant execute on function public.staff_check_in_event_guest(uuid, uuid) to authenticated;
