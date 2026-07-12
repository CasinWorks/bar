-- Admin platform: roles, bans, whitelist, cash time loads, events, guest list, HR

-- Extend roles
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('member', 'staff', 'admin', 'hr'));

alter table public.profiles
  add column if not exists is_banned boolean not null default false,
  add column if not exists is_whitelisted boolean not null default false,
  add column if not exists ban_reason text,
  add column if not exists phone text,
  add column if not exists admin_notes text;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_hr()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'hr'
  );
$$;

create or replace function public.is_admin_or_hr()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.is_admin() or public.is_hr();
$$;

-- Cash-based time loads (admin desk)
create table if not exists public.time_loads (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  loaded_by uuid not null references public.profiles(id),
  seconds_loaded int not null check (seconds_loaded > 0),
  amount_peso int not null default 0 check (amount_peso >= 0),
  payment_method text not null default 'cash'
    check (payment_method in ('cash', 'card', 'complimentary', 'other')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists time_loads_member_id_idx on public.time_loads (member_id);
create index if not exists time_loads_created_at_idx on public.time_loads (created_at desc);

-- Club events / calendar
create table if not exists public.club_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  branch text not null default 'The Blind Tiger — BGC',
  starts_at timestamptz not null,
  ends_at timestamptz,
  capacity int,
  vip_only boolean not null default false,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'completed', 'cancelled')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists club_events_starts_at_idx on public.club_events (starts_at);

-- Guest list per event
create table if not exists public.guest_list_entries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.club_events(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  plus_ones int not null default 0 check (plus_ones >= 0),
  status text not null default 'invited'
    check (status in ('invited', 'confirmed', 'checked_in', 'no_show', 'denied')),
  member_id uuid references public.profiles(id),
  added_by uuid references public.profiles(id),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists guest_list_event_id_idx on public.guest_list_entries (event_id);

-- HR / employment records (staff + management)
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  job_title text not null,
  department text not null default 'floor'
    check (department in ('door', 'bar', 'floor', 'management', 'hr', 'other')),
  employment_status text not null default 'active'
    check (employment_status in ('active', 'on_leave', 'terminated', 'probation')),
  hire_date date,
  hourly_rate_peso int check (hourly_rate_peso is null or hourly_rate_peso >= 0),
  emergency_contact text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Admin load time (cash desk) — callable by service role / admin API
create or replace function public.admin_load_time(
  p_member_id uuid,
  p_seconds int,
  p_amount_peso int default 0,
  p_payment_method text default 'cash',
  p_notes text default null,
  p_admin_id uuid default null
)
returns public.time_loads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.time_loads;
  v_admin uuid;
begin
  if p_seconds < 60 then
    raise exception 'Minimum load is 1 minute.';
  end if;

  v_admin := coalesce(p_admin_id, auth.uid());
  if v_admin is null then
    raise exception 'Admin identity required.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_admin and role in ('admin', 'hr')
  ) then
    raise exception 'Not authorized to load time.';
  end if;

  if exists (
    select 1 from public.profiles
    where id = p_member_id and is_banned
  ) then
    raise exception 'Member is banned.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds + p_seconds
  where id = p_member_id;

  insert into public.time_loads (
    member_id, loaded_by, seconds_loaded, amount_peso, payment_method, notes
  ) values (
    p_member_id, v_admin, p_seconds, coalesce(p_amount_peso, 0),
    coalesce(p_payment_method, 'cash'), p_notes
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.admin_load_time(uuid, int, int, text, text, uuid) to authenticated;
grant execute on function public.admin_load_time(uuid, int, int, text, text, uuid) to service_role;

-- RLS
alter table public.time_loads enable row level security;
alter table public.club_events enable row level security;
alter table public.guest_list_entries enable row level security;
alter table public.employees enable row level security;

-- Admin read/write policies
create policy "time_loads_admin_all"
  on public.time_loads for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

create policy "club_events_admin_all"
  on public.club_events for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

create policy "guest_list_admin_all"
  on public.guest_list_entries for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

create policy "employees_admin_all"
  on public.employees for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

-- Admin can read/update all profiles
create policy "profiles_admin_select"
  on public.profiles for select
  using (public.is_admin_or_hr());

create policy "profiles_admin_update"
  on public.profiles for update
  using (public.is_admin())
  with check (public.is_admin());

-- Members can read own time_loads history
create policy "time_loads_member_select"
  on public.time_loads for select
  using (member_id = auth.uid());

-- Realtime for admin dashboard
alter publication supabase_realtime add table public.time_loads;
