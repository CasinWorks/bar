-- Time packages economy: entry packages, drink allowances, venue activities, bonus time.

create table if not exists public.time_packages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  price_peso int not null,
  duration_minutes int, -- null = until closing (resolved at load)
  included_drinks int, -- null = unlimited (subject to responsible-service soft cap)
  target_guest text,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.venue_activities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  time_cost_minutes int not null,
  description text,
  active boolean not null default true,
  sort_order int not null default 0
);

create table if not exists public.activity_redemptions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.club_sessions(id) on delete cascade,
  member_id uuid not null references public.profiles(id),
  activity_id uuid not null references public.venue_activities(id),
  minutes_charged int not null,
  created_at timestamptz not null default now()
);

create table if not exists public.bonus_time_rules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  minutes int not null,
  variable boolean not null default false,
  active boolean not null default true
);

create table if not exists public.bonus_time_awards (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid references public.bonus_time_rules(id),
  rule_slug text not null,
  member_id uuid not null references public.profiles(id),
  session_id uuid references public.club_sessions(id),
  minutes int not null,
  source text not null default 'staff', -- staff | admin | challenge | system
  notes text,
  awarded_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- Wallet / visit entitlements on profiles
alter table public.profiles
  add column if not exists active_package_slug text,
  add column if not exists included_drinks_remaining int,
  add column if not exists included_drinks_total int,
  add column if not exists package_closing_at timestamptz;

alter table public.club_sessions
  add column if not exists package_slug text,
  add column if not exists included_drinks_remaining int,
  add column if not exists included_drinks_total int,
  add column if not exists closing_at timestamptz,
  add column if not exists experiences_minutes_spent int not null default 0,
  add column if not exists bonus_minutes_earned int not null default 0;

alter table public.time_loads
  add column if not exists package_slug text,
  add column if not exists drinks_granted int;

-- Seed entry packages (screenshot catalog)
insert into public.time_packages (slug, name, price_peso, duration_minutes, included_drinks, target_guest, sort_order)
values
  ('quick-escape', 'Quick Escape', 699, 90, 2, 'After-work crowd', 1),
  ('standard-night', 'Standard Night', 999, 180, 4, 'Most guests', 2),
  ('after-hours', 'After Hours', 1299, 240, 5, 'Late-night / weekend', 3),
  ('unlimited', 'Unlimited', 1799, null, null, 'VIP / Members', 4)
on conflict (slug) do update set
  name = excluded.name,
  price_peso = excluded.price_peso,
  duration_minutes = excluded.duration_minutes,
  included_drinks = excluded.included_drinks,
  target_guest = excluded.target_guest,
  sort_order = excluded.sort_order,
  active = true;

insert into public.venue_activities (slug, name, time_cost_minutes, description, sort_order)
values
  ('vip-lounge', 'VIP Lounge', 30, 'Private lounge access', 1),
  ('secret-room', 'Secret Room', 45, 'Members-only room', 2),
  ('photo-booth', 'Photo Booth', 5, 'Instant night memorabilia', 3),
  ('dj-meet', 'DJ Meet & Greet', 15, 'Meet the booth', 4),
  ('private-booth', 'Private Booth', 30, 'Reserved booth time', 5)
on conflict (slug) do update set
  name = excluded.name,
  time_cost_minutes = excluded.time_cost_minutes,
  description = excluded.description,
  sort_order = excluded.sort_order,
  active = true;

insert into public.bonus_time_rules (slug, name, minutes, variable)
values
  ('birthday', 'Birthday Celebration', 15, false),
  ('bring-a-friend', 'Bring a Friend', 20, false),
  ('club-games', 'Win Club Games', 30, false),
  ('dance-competition', 'Dance Competition Winner', 60, false),
  ('social-media', 'Social Media Promotion', 10, false),
  ('loyalty-daily', 'Loyalty Membership', 10, false),
  ('special-events', 'Special Events', 0, true)
on conflict (slug) do update set
  name = excluded.name,
  minutes = excluded.minutes,
  variable = excluded.variable,
  active = true;

-- Responsible-service soft cap when package drinks are unlimited
create or replace function public.responsible_drink_cap()
returns int language sql immutable as $$ select 12 $$;

-- Load a named time package onto a member wallet (+ drink allowance).
create or replace function public.admin_load_package(
  p_member_id uuid,
  p_package_slug text,
  p_payment_method text default 'cash',
  p_notes text default null,
  p_admin_id uuid default null,
  p_quantity int default 1
)
returns public.time_loads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pkg public.time_packages;
  v_qty int := greatest(1, least(coalesce(p_quantity, 1), 10));
  v_minutes int;
  v_seconds int;
  v_peso int;
  v_drinks int;
  v_closing timestamptz;
  v_row public.time_loads;
  v_banned boolean;
begin
  select * into v_pkg from public.time_packages where slug = p_package_slug and active = true;
  if not found then
    raise exception 'Unknown or inactive package: %', p_package_slug;
  end if;

  select is_banned into v_banned from public.profiles where id = p_member_id;
  if v_banned then
    raise exception 'Account is banned';
  end if;

  if v_pkg.duration_minutes is null then
    -- Until closing: credit through 4:00 AM local next day (approx 8h soft launch default)
    v_minutes := 480 * v_qty;
    v_closing := date_trunc('day', now() at time zone 'Asia/Manila')
      + interval '1 day' + interval '4 hours';
    v_closing := v_closing at time zone 'Asia/Manila';
  else
    v_minutes := v_pkg.duration_minutes * v_qty;
    v_closing := null;
  end if;

  v_seconds := v_minutes * 60;
  v_peso := case when p_payment_method = 'complimentary' then 0 else v_pkg.price_peso * v_qty end;

  if v_pkg.included_drinks is null then
    v_drinks := public.responsible_drink_cap() * v_qty;
  else
    v_drinks := v_pkg.included_drinks * v_qty;
  end if;

  update public.profiles
  set
    time_balance_seconds = coalesce(time_balance_seconds, 0) + v_seconds,
    active_package_slug = v_pkg.slug,
    included_drinks_remaining = coalesce(included_drinks_remaining, 0) + v_drinks,
    included_drinks_total = coalesce(included_drinks_total, 0) + v_drinks,
    package_closing_at = coalesce(v_closing, package_closing_at)
  where id = p_member_id;

  insert into public.time_loads (
    member_id, seconds_loaded, amount_peso, payment_method, notes, loaded_by, package_slug, drinks_granted, status
  ) values (
    p_member_id, v_seconds, v_peso, coalesce(p_payment_method, 'cash'), p_notes, p_admin_id, v_pkg.slug, v_drinks, 'posted'
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.admin_load_package(uuid, text, text, text, uuid, int) to authenticated;
grant execute on function public.admin_load_package(uuid, text, text, text, uuid, int) to service_role;

-- Staff/admin awards bonus minutes from a rule.
create or replace function public.admin_award_bonus_time(
  p_member_id uuid,
  p_rule_slug text,
  p_minutes int default null,
  p_notes text default null,
  p_admin_id uuid default null,
  p_session_id uuid default null
)
returns public.bonus_time_awards
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rule public.bonus_time_rules;
  v_minutes int;
  v_row public.bonus_time_awards;
begin
  select * into v_rule from public.bonus_time_rules where slug = p_rule_slug and active = true;
  if not found then
    raise exception 'Unknown bonus rule: %', p_rule_slug;
  end if;

  v_minutes := coalesce(p_minutes, v_rule.minutes);
  if v_minutes is null or v_minutes < 1 then
    raise exception 'Minutes required for this bonus';
  end if;

  update public.profiles
  set time_balance_seconds = coalesce(time_balance_seconds, 0) + (v_minutes * 60)
  where id = p_member_id;

  insert into public.bonus_time_awards (
    rule_id, rule_slug, member_id, session_id, minutes, source, notes, awarded_by
  ) values (
    v_rule.id, v_rule.slug, p_member_id, p_session_id, v_minutes, 'admin', p_notes, p_admin_id
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.admin_award_bonus_time(uuid, text, int, text, uuid, uuid) to authenticated;
grant execute on function public.admin_award_bonus_time(uuid, text, int, text, uuid, uuid) to service_role;

alter table public.time_packages enable row level security;
alter table public.venue_activities enable row level security;
alter table public.activity_redemptions enable row level security;
alter table public.bonus_time_rules enable row level security;
alter table public.bonus_time_awards enable row level security;

create policy "time_packages_read_all" on public.time_packages for select using (true);
create policy "venue_activities_read_all" on public.venue_activities for select using (true);
create policy "bonus_rules_read_all" on public.bonus_time_rules for select using (true);

create policy "activity_redemptions_member" on public.activity_redemptions for select
  using (auth.uid() = member_id);
create policy "bonus_awards_member" on public.bonus_time_awards for select
  using (auth.uid() = member_id);
