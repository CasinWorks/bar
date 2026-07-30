-- Event backend contract: request workflow, unique invites, accepted guests,
-- event wallet ledger, staff check-in, and push-compatible host notifications.

create or replace function public.is_staff_or_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('staff', 'admin')
  );
$$;

create or replace function public.event_guest_identity_key(
  p_name text,
  p_email text default null,
  p_phone text default null
)
returns text
language sql
immutable
as $$
  select case
    when nullif(lower(trim(coalesce(p_email, ''))), '') is not null then
      'email:' || lower(trim(p_email))
    when nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9]+', '', 'g'), '') is not null then
      'phone:' || regexp_replace(coalesce(p_phone, ''), '[^0-9]+', '', 'g')
    else
      'name:' || lower(regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g'))
  end;
$$;

create or replace function public.generate_event_invite_token()
returns text
language sql
as $$
  select encode(gen_random_bytes(16), 'hex');
$$;

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
    and now() <= p_ends_at;
$$;

alter table public.club_events
  add column if not exists request_submitted_at timestamptz not null default now(),
  add column if not exists rejected_at timestamptz,
  add column if not exists wallet_total_extended_seconds int not null default 0,
  add column if not exists wallet_consumed_seconds int not null default 0,
  add column if not exists wallet_low_notified_at timestamptz;

alter table public.club_events drop constraint if exists club_events_wallet_total_extended_seconds_check;
alter table public.club_events
  add constraint club_events_wallet_total_extended_seconds_check
  check (wallet_total_extended_seconds >= 0);

alter table public.club_events drop constraint if exists club_events_wallet_consumed_seconds_check;
alter table public.club_events
  add constraint club_events_wallet_consumed_seconds_check
  check (wallet_consumed_seconds >= 0);

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

  new.request_submitted_at := coalesce(new.request_submitted_at, now());
  return new;
end;
$$;

drop trigger if exists trg_validate_club_event_request on public.club_events;
create trigger trg_validate_club_event_request
  before insert or update on public.club_events
  for each row
  execute function public.validate_club_event_request();

create table if not exists public.event_invites (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.club_events(id) on delete cascade,
  guest_name text not null,
  guest_email text,
  guest_phone text,
  guest_identity_key text not null,
  invite_code text not null,
  invite_token text not null default public.generate_event_invite_token(),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked', 'expired', 'checked_in')),
  created_by uuid references public.profiles(id) on delete set null,
  accepted_by uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  last_sent_at timestamptz,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (invite_code),
  unique (invite_token)
);

create unique index if not exists event_invites_event_guest_identity_idx
  on public.event_invites (event_id, guest_identity_key);

create index if not exists event_invites_event_status_idx
  on public.event_invites (event_id, status, created_at desc);

create index if not exists event_invites_accepted_by_idx
  on public.event_invites (accepted_by, accepted_at desc)
  where accepted_by is not null;

create table if not exists public.event_guests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.club_events(id) on delete cascade,
  invite_id uuid not null unique references public.event_invites(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  guest_name text not null,
  guest_email text,
  guest_phone text,
  status text not null default 'accepted'
    check (status in ('accepted', 'checked_in', 'revoked', 'cancelled')),
  accepted_at timestamptz not null default now(),
  checked_in_at timestamptz,
  checked_in_by uuid references public.profiles(id) on delete set null,
  club_session_id uuid references public.club_sessions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, member_id)
);

create index if not exists event_guests_member_idx
  on public.event_guests (member_id, accepted_at desc);

create index if not exists event_guests_event_status_idx
  on public.event_guests (event_id, status, accepted_at desc);

create index if not exists event_guests_session_idx
  on public.event_guests (club_session_id)
  where club_session_id is not null;

create table if not exists public.event_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.club_events(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  event_guest_id uuid references public.event_guests(id) on delete set null,
  order_id uuid references public.drink_orders(id) on delete set null,
  kind text not null
    check (kind in ('seed', 'extension', 'drink_charge', 'admin_adjustment', 'refund')),
  seconds_delta int not null,
  balance_after_seconds int not null check (balance_after_seconds >= 0),
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists event_wallet_transactions_event_idx
  on public.event_wallet_transactions (event_id, created_at desc);

create index if not exists event_wallet_transactions_guest_idx
  on public.event_wallet_transactions (event_guest_id, created_at desc)
  where event_guest_id is not null;

create or replace function public.touch_event_invites_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.guest_identity_key := public.event_guest_identity_key(new.guest_name, new.guest_email, new.guest_phone);
  new.invite_code := upper(trim(new.invite_code));
  new.invite_token := lower(trim(new.invite_token));
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_event_invites_updated_at on public.event_invites;
create trigger trg_event_invites_updated_at
  before insert or update on public.event_invites
  for each row
  execute function public.touch_event_invites_updated_at();

create or replace function public.touch_event_guests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_event_guests_updated_at on public.event_guests;
create trigger trg_event_guests_updated_at
  before insert or update on public.event_guests
  for each row
  execute function public.touch_event_guests_updated_at();

alter table public.event_invites enable row level security;
alter table public.event_guests enable row level security;
alter table public.event_wallet_transactions enable row level security;

drop policy if exists "club_events_member_select" on public.club_events;
create policy "club_events_member_select"
  on public.club_events for select
  using (
    approval_status = 'approved'
    or requested_by = auth.uid()
    or host_id = auth.uid()
    or public.is_admin_or_hr()
    or (approval_status = 'approved' and public.is_staff_or_admin())
  );

drop policy if exists "event_invites_host_select" on public.event_invites;
create policy "event_invites_host_select"
  on public.event_invites for select
  using (
    accepted_by = auth.uid()
    or exists (
      select 1
      from public.club_events ce
      where ce.id = event_id
        and (
          ce.host_id = auth.uid()
          or ce.requested_by = auth.uid()
          or public.is_admin_or_hr()
          or (ce.approval_status = 'approved' and public.is_staff_or_admin())
        )
    )
  );

drop policy if exists "event_invites_admin_all" on public.event_invites;
create policy "event_invites_admin_all"
  on public.event_invites for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

drop policy if exists "event_guests_select_authorized" on public.event_guests;
create policy "event_guests_select_authorized"
  on public.event_guests for select
  using (
    member_id = auth.uid()
    or exists (
      select 1
      from public.club_events ce
      where ce.id = event_id
        and (
          ce.host_id = auth.uid()
          or ce.requested_by = auth.uid()
          or public.is_admin_or_hr()
          or (ce.approval_status = 'approved' and public.is_staff_or_admin())
        )
    )
  );

drop policy if exists "event_guests_admin_all" on public.event_guests;
create policy "event_guests_admin_all"
  on public.event_guests for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

drop policy if exists "event_wallet_transactions_select_authorized" on public.event_wallet_transactions;
create policy "event_wallet_transactions_select_authorized"
  on public.event_wallet_transactions for select
  using (
    exists (
      select 1
      from public.club_events ce
      where ce.id = event_id
        and (
          ce.host_id = auth.uid()
          or ce.requested_by = auth.uid()
          or public.is_admin_or_hr()
          or (ce.approval_status = 'approved' and public.is_staff_or_admin())
        )
    )
  );

drop policy if exists "event_wallet_transactions_admin_all" on public.event_wallet_transactions;
create policy "event_wallet_transactions_admin_all"
  on public.event_wallet_transactions for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

with ranked_guest_list_entries as (
  select
    gle.*,
    public.event_guest_identity_key(gle.name, gle.email, gle.phone) as guest_identity_key,
    row_number() over (
      partition by gle.event_id, public.event_guest_identity_key(gle.name, gle.email, gle.phone)
      order by
        case gle.status
          when 'checked_in' then 1
          when 'registered' then 2
          when 'confirmed' then 3
          when 'invited' then 4
          when 'no_show' then 5
          when 'revoked' then 6
          when 'denied' then 7
          else 8
        end,
        coalesce(gle.checked_in_at, gle.accepted_at, gle.invite_claimed_at, gle.invited_at, gle.created_at) desc,
        case when nullif(trim(gle.invite_code), '') is not null then 0 else 1 end,
        gle.created_at desc,
        gle.id desc
    ) as identity_rank
  from public.guest_list_entries gle
)
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
  gle.guest_identity_key,
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
from ranked_guest_list_entries gle
where gle.identity_rank = 1
on conflict (event_id, guest_identity_key) do update
set invite_code = excluded.invite_code;

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

insert into public.event_wallet_transactions (
  event_id,
  actor_id,
  kind,
  seconds_delta,
  balance_after_seconds,
  note,
  created_at
)
select
  ce.id,
  coalesce(ce.requested_by, ce.created_by),
  'seed',
  ce.wallet_seconds,
  ce.wallet_seconds,
  'Opening balance at contract migration.',
  coalesce(ce.wallet_last_extended_at, ce.request_submitted_at, ce.created_at)
from public.club_events ce
where ce.wallet_seconds > 0
  and not exists (
    select 1
    from public.event_wallet_transactions ewt
    where ewt.event_id = ce.id
  );

alter table public.drink_orders
  add column if not exists event_id uuid references public.club_events(id) on delete set null,
  add column if not exists event_guest_id uuid references public.event_guests(id) on delete set null;

alter table public.drink_orders drop constraint if exists drink_orders_charge_source_check;
alter table public.drink_orders
  add constraint drink_orders_charge_source_check
  check (
    charge_source in (
      'personalTime',
      'vipRoomTab',
      'packageAllowance',
      'cashAtBar',
      'eventWallet'
    )
  );

alter table public.drink_orders drop constraint if exists drink_orders_event_wallet_check;
alter table public.drink_orders
  add constraint drink_orders_event_wallet_check
  check (
    (charge_source = 'eventWallet' and event_id is not null)
    or (charge_source <> 'eventWallet')
  );

create index if not exists drink_orders_event_id_idx
  on public.drink_orders (event_id, ordered_at desc)
  where event_id is not null;

create index if not exists drink_orders_event_guest_id_idx
  on public.drink_orders (event_guest_id, ordered_at desc)
  where event_guest_id is not null;

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
    'host_id', ce.host_id,
    'host_name', coalesce(ce.host_name, 'Host')
  )
  from public.event_invites ei
  join public.club_events ce on ce.id = ei.event_id
  where ei.invite_token = lower(trim(coalesce(p_token, '')))
  limit 1;
$$;

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
    p_invites
  );
$$;

create or replace function public.admin_review_event_request(
  p_event_id uuid,
  p_decision text,
  p_admin_review_notes text default null
)
returns public.club_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events;
  v_decision text := lower(trim(coalesce(p_decision, '')));
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  if v_decision not in ('approved', 'rejected', 'needs_revision') then
    raise exception 'Invalid review decision.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event request not found.';
  end if;

  update public.club_events
  set approval_status = v_decision,
      admin_review_notes = nullif(trim(coalesce(p_admin_review_notes, '')), ''),
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      approved_at = case when v_decision = 'approved' then now() else approved_at end,
      rejected_at = case when v_decision = 'rejected' then now() else null end
  where id = p_event_id
  returning * into v_event;

  insert into public.member_notifications (
    sender_id,
    recipient_id,
    kind,
    message,
    metadata
  ) values (
    auth.uid(),
    coalesce(v_event.requested_by, v_event.host_id),
    case v_decision
      when 'approved' then 'event_request_approved'
      when 'rejected' then 'event_request_rejected'
      else 'event_request_needs_revision'
    end,
    case v_decision
      when 'approved' then 'Your event request "' || v_event.title || '" was approved.'
      when 'rejected' then 'Your event request "' || v_event.title || '" was rejected.'
      else 'Your event request "' || v_event.title || '" needs revision.'
    end,
    jsonb_build_object(
      'event_id', v_event.id,
      'event_title', v_event.title,
      'approval_status', v_event.approval_status,
      'review_notes', v_event.admin_review_notes
    )
  );

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

create or replace function public.accept_event_invite_by_token(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  select invite_code
    into v_code
  from public.event_invites
  where invite_token = lower(trim(coalesce(p_token, '')))
  limit 1;

  if v_code is null then
    raise exception 'Invite token not found.';
  end if;

  return public.accept_event_invite(v_code, 'token');
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

create or replace function public.list_event_invites(p_event_id uuid)
returns setof public.event_invites
language sql
security definer
set search_path = public
stable
as $$
  select ei.*
  from public.event_invites ei
  join public.club_events ce on ce.id = ei.event_id
  where ei.event_id = p_event_id
    and (
      ce.host_id = auth.uid()
      or ce.requested_by = auth.uid()
      or public.is_admin_or_hr()
      or public.is_staff_or_admin()
    )
  order by ei.created_at asc;
$$;

create or replace function public.list_event_guests(p_event_id uuid)
returns setof public.event_guests
language sql
security definer
set search_path = public
stable
as $$
  select eg.*
  from public.event_guests eg
  join public.club_events ce on ce.id = eg.event_id
  where eg.event_id = p_event_id
    and (
      ce.host_id = auth.uid()
      or ce.requested_by = auth.uid()
      or public.is_admin_or_hr()
      or public.is_staff_or_admin()
    )
  order by eg.accepted_at asc;
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

  select *
    into v_event
  from public.club_events
  where id = p_event_id
    and (
      host_id = auth.uid()
      or requested_by = auth.uid()
      or public.is_admin_or_hr()
    )
  for update;

  if not found then
    raise exception 'Hosted event not found.';
  end if;

  v_add_seconds := p_minutes * 60;

  update public.club_events
  set wallet_seconds = wallet_seconds + v_add_seconds,
      wallet_total_extended_seconds = wallet_total_extended_seconds + v_add_seconds,
      wallet_last_extended_at = now(),
      wallet_low_notified_at = null
  where id = p_event_id
  returning * into v_event;

  insert into public.event_wallet_transactions (
    event_id,
    actor_id,
    kind,
    seconds_delta,
    balance_after_seconds,
    note
  ) values (
    p_event_id,
    auth.uid(),
    'extension',
    v_add_seconds,
    v_event.wallet_seconds,
    'Host event wallet extension.'
  );

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
  v_guest public.event_guests;
  v_previous_balance int;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  if p_seconds <= 0 then
    raise exception 'Invalid spend amount.';
  end if;

  select *
    into v_guest
  from public.event_guests
  where event_id = p_event_id
    and member_id = auth.uid()
    and status = 'checked_in'
  for update;

  if not found then
    raise exception 'You are not checked in for this event.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = p_event_id
    and approval_status = 'approved'
    and public.is_event_active(starts_at, ends_at)
  for update;

  if not found then
    raise exception 'Event is not active.';
  end if;

  if v_event.wallet_seconds < p_seconds then
    raise exception 'Event wallet needs more time.';
  end if;

  v_previous_balance := v_event.wallet_seconds;

  update public.club_events
  set wallet_seconds = wallet_seconds - p_seconds,
      wallet_consumed_seconds = wallet_consumed_seconds + p_seconds
  where id = p_event_id
  returning * into v_event;

  insert into public.event_wallet_transactions (
    event_id,
    actor_id,
    event_guest_id,
    order_id,
    kind,
    seconds_delta,
    balance_after_seconds,
    note,
    metadata
  ) values (
    p_event_id,
    auth.uid(),
    v_guest.id,
    p_order_id,
    'drink_charge',
    -p_seconds,
    v_event.wallet_seconds,
    'Drink charged against event wallet.',
    jsonb_build_object(
      'member_id', auth.uid(),
      'club_session_id', v_guest.club_session_id
    )
  );

  if v_event.host_id is not null
     and v_event.wallet_seconds <= v_event.wallet_low_threshold_seconds
     and (
       v_previous_balance > v_event.wallet_low_threshold_seconds
       or v_event.wallet_low_notified_at is null
     ) then
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
      coalesce(v_guest.guest_name, 'A guest') || ' used event time for a drink. Event wallet is running low.',
      jsonb_build_object(
        'event_id', v_event.id,
        'event_title', v_event.title,
        'remaining_seconds', v_event.wallet_seconds,
        'order_id', p_order_id
      )
    );

    update public.club_events
    set wallet_low_notified_at = now()
    where id = p_event_id
    returning * into v_event;
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'event_guest_id', v_guest.id,
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
  v_session public.club_sessions%rowtype;
  v_match_count int;
  v_guest public.event_guests%rowtype;
  v_event public.club_events%rowtype;
  v_event_id uuid;
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff access required.';
  end if;

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
    and ce.approval_status = 'approved'
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
    and ce.approval_status = 'approved'
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

create or replace function public.staff_check_in_event_guest_for_session(
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
begin
  select member_id
    into v_member_id
  from public.club_sessions
  where id = p_session_id;

  if v_member_id is null then
    raise exception 'Club session not found.';
  end if;

  return public.staff_check_in_event_guest(v_member_id, p_session_id);
end;
$$;

grant execute on function public.fetch_event_invite_by_code(text) to anon, authenticated;
grant execute on function public.fetch_event_invite_by_token(text) to anon, authenticated;
grant execute on function public.submit_event_request(text, text, text, text, timestamptz, timestamptz, int, text, text, int, jsonb) to authenticated;
grant execute on function public.create_event_request(text, text, text, text, timestamptz, timestamptz, int, text, text, int, jsonb) to authenticated;
grant execute on function public.admin_review_event_request(uuid, text, text) to authenticated;
grant execute on function public.accept_event_invite(text, text) to authenticated;
grant execute on function public.accept_event_invite_by_token(text) to authenticated;
grant execute on function public.list_my_hosted_events() to authenticated;
grant execute on function public.list_event_invites(uuid) to authenticated;
grant execute on function public.list_event_guests(uuid) to authenticated;
grant execute on function public.list_my_event_invites() to authenticated;
grant execute on function public.get_active_event_for_member(uuid) to authenticated;
grant execute on function public.extend_event_wallet(uuid, int) to authenticated;
grant execute on function public.consume_event_wallet_for_drink(uuid, int, uuid) to authenticated;
grant execute on function public.staff_check_in_event_guest(uuid, uuid) to authenticated;
grant execute on function public.staff_check_in_event_guest_for_session(uuid) to authenticated;

do $$
begin
  begin
    alter publication supabase_realtime add table public.event_invites;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.event_guests;
  exception when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.event_wallet_transactions;
  exception when duplicate_object then null;
  end;
end $$;
