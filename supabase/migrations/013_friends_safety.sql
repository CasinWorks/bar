-- Friends + safety layer: mutual nearby friends, blocking, reports, ride/insurance placeholders

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> recipient_id)
);

create unique index if not exists friend_requests_pair_pending_idx
  on public.friend_requests (least(requester_id, recipient_id), greatest(requester_id, recipient_id))
  where status = 'pending';

create index if not exists friend_requests_recipient_idx
  on public.friend_requests (recipient_id, status);

create table if not exists public.member_friendships (
  member_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (member_id, friend_id),
  check (member_id <> friend_id)
);

create index if not exists member_friendships_friend_idx
  on public.member_friendships (friend_id);

create table if not exists public.member_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists member_blocks_blocked_idx
  on public.member_blocks (blocked_id);

create table if not exists public.member_notifications (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references public.profiles(id) on delete set null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'friend_ping',
  message text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists member_notifications_recipient_idx
  on public.member_notifications (recipient_id, created_at desc);

create table if not exists public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_member_id uuid references public.profiles(id) on delete set null,
  category text not null default 'other',
  description text,
  branch text,
  session_id uuid,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists safety_reports_reporter_idx
  on public.safety_reports (reporter_id, created_at desc);

create table if not exists public.ride_assist_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  pickup_branch text,
  destination text,
  provider text not null default 'grab',
  status text not null default 'pending'
    check (status in ('pending', 'staff_notified', 'opened_partner', 'cancelled', 'completed')),
  external_url text,
  partner_reference text,
  created_at timestamptz not null default now()
);

create index if not exists ride_assist_requests_requester_idx
  on public.ride_assist_requests (requester_id, created_at desc);

create table if not exists public.insurance_incidents (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid references public.safety_reports(id) on delete set null,
  incident_type text not null default 'general',
  consent_to_share boolean not null default false,
  status text not null default 'draft'
    check (status in ('draft', 'stored', 'submitted', 'closed')),
  partner_reference text,
  created_at timestamptz not null default now()
);

create index if not exists insurance_incidents_reporter_idx
  on public.insurance_incidents (reporter_id, created_at desc);

alter table public.friend_requests enable row level security;
alter table public.member_friendships enable row level security;
alter table public.member_blocks enable row level security;
alter table public.member_notifications enable row level security;
alter table public.safety_reports enable row level security;
alter table public.ride_assist_requests enable row level security;
alter table public.insurance_incidents enable row level security;

create policy "friend_requests_select_self"
  on public.friend_requests for select
  using (requester_id = auth.uid() or recipient_id = auth.uid());

create policy "friend_requests_no_direct_insert"
  on public.friend_requests for insert
  with check (false);

create policy "friendships_select_self"
  on public.member_friendships for select
  using (member_id = auth.uid() or friend_id = auth.uid());

create policy "friendships_no_direct_insert"
  on public.member_friendships for insert
  with check (false);

create policy "blocks_select_self"
  on public.member_blocks for select
  using (blocker_id = auth.uid() or blocked_id = auth.uid());

create policy "blocks_no_direct_insert"
  on public.member_blocks for insert
  with check (false);

create policy "notifications_select_self"
  on public.member_notifications for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy "notifications_no_direct_insert"
  on public.member_notifications for insert
  with check (false);

create policy "safety_reports_select_self"
  on public.safety_reports for select
  using (reporter_id = auth.uid());

create policy "safety_reports_no_direct_insert"
  on public.safety_reports for insert
  with check (false);

create policy "ride_requests_select_self"
  on public.ride_assist_requests for select
  using (requester_id = auth.uid());

create policy "ride_requests_no_direct_insert"
  on public.ride_assist_requests for insert
  with check (false);

create policy "insurance_incidents_select_self"
  on public.insurance_incidents for select
  using (reporter_id = auth.uid());

create policy "insurance_incidents_no_direct_insert"
  on public.insurance_incidents for insert
  with check (false);

create or replace function public.has_member_block(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.member_blocks
    where (blocker_id = p_a and blocked_id = p_b)
       or (blocker_id = p_b and blocked_id = p_a)
  );
$$;

create or replace function public.search_friend_candidates(p_query text)
returns table (
  member_id uuid,
  display_name text,
  email text,
  branch text,
  is_nearby boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, coalesce(p.name, 'Guest'), p.email, p.branch, false
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.role = 'member'
    and not public.has_member_block(auth.uid(), p.id)
    and (
      length(trim(coalesce(p_query, ''))) = 0
      or p.name ilike '%' || trim(p_query) || '%'
      or p.email ilike '%' || trim(p_query) || '%'
      or p.phone ilike '%' || trim(p_query) || '%'
    )
  order by p.name
  limit 12;
$$;

create or replace function public.send_friend_request(p_recipient_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.friend_requests;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if p_recipient_id = auth.uid() then
    raise exception 'You cannot add yourself.';
  end if;
  if public.has_member_block(auth.uid(), p_recipient_id) then
    raise exception 'Friend request unavailable.';
  end if;
  if exists (
    select 1 from public.member_friendships
    where member_id = auth.uid() and friend_id = p_recipient_id
  ) then
    raise exception 'Already friends.';
  end if;

  insert into public.friend_requests (requester_id, recipient_id, status)
  values (auth.uid(), p_recipient_id, 'pending')
  on conflict do nothing
  returning * into v_row;

  if v_row.id is null then
    select *
      into v_row
    from public.friend_requests
    where status = 'pending'
      and least(requester_id, recipient_id) = least(auth.uid(), p_recipient_id)
      and greatest(requester_id, recipient_id) = greatest(auth.uid(), p_recipient_id)
    limit 1;
  end if;

  return v_row;
end;
$$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.friend_requests;
begin
  select *
    into v_row
  from public.friend_requests
  where id = p_request_id
    and recipient_id = auth.uid()
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Friend request not found.';
  end if;
  if public.has_member_block(v_row.requester_id, v_row.recipient_id) then
    raise exception 'Friend request unavailable.';
  end if;

  update public.friend_requests
  set status = 'accepted', responded_at = now()
  where id = p_request_id
  returning * into v_row;

  insert into public.member_friendships (member_id, friend_id)
  values (v_row.requester_id, v_row.recipient_id), (v_row.recipient_id, v_row.requester_id)
  on conflict do nothing;

  return v_row;
end;
$$;

create or replace function public.decline_friend_request(p_request_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.friend_requests;
begin
  update public.friend_requests
  set status = 'declined', responded_at = now()
  where id = p_request_id
    and recipient_id = auth.uid()
    and status = 'pending'
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Friend request not found.';
  end if;

  return v_row;
end;
$$;

create or replace function public.list_friend_requests()
returns table (
  id uuid,
  requester_id uuid,
  requester_name text,
  recipient_id uuid,
  recipient_name text,
  status text,
  created_at timestamptz,
  responded_at timestamptz,
  direction text
)
language sql
security definer
set search_path = public
stable
as $$
  select fr.id,
         fr.requester_id,
         coalesce(req.name, 'Guest') as requester_name,
         fr.recipient_id,
         coalesce(rec.name, 'Guest') as recipient_name,
         fr.status,
         fr.created_at,
         fr.responded_at,
         case when fr.recipient_id = auth.uid() then 'inbound' else 'outbound' end as direction
  from public.friend_requests fr
  join public.profiles req on req.id = fr.requester_id
  join public.profiles rec on rec.id = fr.recipient_id
  where fr.requester_id = auth.uid() or fr.recipient_id = auth.uid()
  order by fr.created_at desc;
$$;

create or replace function public.list_mutual_friends_nearby(p_branch text)
returns table (
  member_id uuid,
  display_name text,
  email text,
  branch text,
  vibe_tag text,
  updated_at timestamptz,
  is_nearby boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id,
         coalesce(p.name, 'Guest') as display_name,
         p.email,
         sp.branch,
         sp.vibe_tag,
         sp.updated_at,
         true as is_nearby
  from public.member_friendships mf
  join public.profiles p on p.id = mf.friend_id
  join public.social_presence sp on sp.member_id = mf.friend_id
  where mf.member_id = auth.uid()
    and sp.open_to_meet = true
    and sp.branch = p_branch
    and sp.updated_at > now() - interval '6 hours'
    and not public.has_member_block(auth.uid(), mf.friend_id)
  order by sp.updated_at desc;
$$;

create or replace function public.notify_friend(p_friend_id uuid, p_message text)
returns public.member_notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.member_notifications;
begin
  if not exists (
    select 1 from public.member_friendships
    where member_id = auth.uid() and friend_id = p_friend_id
  ) then
    raise exception 'Friend not found.';
  end if;
  if public.has_member_block(auth.uid(), p_friend_id) then
    raise exception 'Notification unavailable.';
  end if;

  insert into public.member_notifications (sender_id, recipient_id, kind, message)
  values (auth.uid(), p_friend_id, 'friend_ping', coalesce(nullif(trim(p_message), ''), 'I am here.'))
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.block_member(p_blocked_id uuid, p_reason text default null)
returns public.member_blocks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.member_blocks;
begin
  if p_blocked_id = auth.uid() then
    raise exception 'You cannot block yourself.';
  end if;

  insert into public.member_blocks (blocker_id, blocked_id, reason)
  values (auth.uid(), p_blocked_id, p_reason)
  on conflict (blocker_id, blocked_id) do update
    set reason = excluded.reason,
        created_at = now()
  returning * into v_row;

  delete from public.member_friendships
  where (member_id = auth.uid() and friend_id = p_blocked_id)
     or (member_id = p_blocked_id and friend_id = auth.uid());

  return v_row;
end;
$$;

create or replace function public.unblock_member(p_blocked_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.member_blocks
  where blocker_id = auth.uid() and blocked_id = p_blocked_id;
  return true;
end;
$$;

create or replace function public.submit_safety_report(
  p_category text,
  p_description text default null,
  p_reported_member_id uuid default null,
  p_branch text default null,
  p_session_id uuid default null
)
returns public.safety_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.safety_reports;
begin
  insert into public.safety_reports (
    reporter_id, reported_member_id, category, description, branch, session_id
  ) values (
    auth.uid(),
    p_reported_member_id,
    coalesce(nullif(trim(p_category), ''), 'other'),
    nullif(trim(coalesce(p_description, '')), ''),
    nullif(trim(coalesce(p_branch, '')), ''),
    p_session_id
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.request_ride_assist(
  p_pickup_branch text,
  p_destination text,
  p_provider text default 'grab',
  p_external_url text default null
)
returns public.ride_assist_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.ride_assist_requests;
begin
  insert into public.ride_assist_requests (
    requester_id, pickup_branch, destination, provider, status, external_url
  ) values (
    auth.uid(),
    nullif(trim(coalesce(p_pickup_branch, '')), ''),
    nullif(trim(coalesce(p_destination, '')), ''),
    coalesce(nullif(trim(p_provider), ''), 'grab'),
    'staff_notified',
    p_external_url
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.create_insurance_incident(
  p_incident_type text,
  p_report_id uuid default null,
  p_consent_to_share boolean default false
)
returns public.insurance_incidents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.insurance_incidents;
begin
  insert into public.insurance_incidents (
    reporter_id, report_id, incident_type, consent_to_share, status, partner_reference
  ) values (
    auth.uid(),
    p_report_id,
    coalesce(nullif(trim(p_incident_type), ''), 'general'),
    coalesce(p_consent_to_share, false),
    case when coalesce(p_consent_to_share, false) then 'stored' else 'draft' end,
    'BT-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.list_whos_inside(p_branch text)
returns setof public.social_presence
language sql
security definer
set search_path = public
stable
as $$
  select *
  from public.social_presence sp
  where sp.open_to_meet = true
    and sp.branch = p_branch
    and sp.updated_at > now() - interval '6 hours'
    and not public.has_member_block(auth.uid(), sp.member_id)
  order by sp.updated_at desc;
$$;

create or replace function public.join_meet(p_code text)
returns public.social_meets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_row public.social_meets;
  v_norm text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  v_norm := upper(trim(p_code));
  select name into v_name from public.profiles where id = auth.uid();

  select * into v_row
  from public.social_meets
  where code = v_norm
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Meet not found or already claimed.';
  end if;
  if v_row.host_id = auth.uid() then
    raise exception 'You cannot join your own meet.';
  end if;
  if public.has_member_block(auth.uid(), v_row.host_id) then
    raise exception 'Meet unavailable.';
  end if;

  update public.social_meets
  set guest_id = auth.uid(),
      guest_name = coalesce(v_name, ''),
      status = 'matched',
      matched_at = now()
  where id = v_row.id
  returning * into v_row;

  update public.profiles
  set time_balance_seconds = time_balance_seconds + v_row.seconds
  where id = auth.uid();

  return v_row;
end;
$$;
