-- Blind Tiger: profiles + club sessions with role-based access

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  email text not null default '',
  birthdate date,
  role text not null default 'member' check (role in ('member', 'staff')),
  branch text,
  created_at timestamptz not null default now()
);

create table if not exists public.club_sessions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  member_name text not null,
  branch text not null,
  purchased_seconds int not null,
  remaining_seconds int not null default 0,
  amount_paid int not null,
  phase text not null default 'paid_awaiting_entry' check (
    phase in ('paid_awaiting_entry', 'inside_club', 'awaiting_exit_scan', 'completed')
  ),
  drinks_ordered int not null default 0,
  entered_at timestamptz,
  exited_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists club_sessions_member_id_idx on public.club_sessions (member_id);
create index if not exists club_sessions_phase_idx on public.club_sessions (phase);

alter table public.profiles enable row level security;
alter table public.club_sessions enable row level security;

-- Profiles: read own row
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

-- Profiles: staff can read all profiles
create policy "profiles_select_staff"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'staff'
    )
  );

-- Profiles: users can update own name (not role)
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Sessions: members insert own
create policy "sessions_insert_member"
  on public.club_sessions for insert
  with check (member_id = auth.uid());

-- Sessions: members read own
create policy "sessions_select_member"
  on public.club_sessions for select
  using (member_id = auth.uid());

-- Sessions: members update own (timer, drinks, request exit)
create policy "sessions_update_member"
  on public.club_sessions for update
  using (member_id = auth.uid());

-- Sessions: staff read all
create policy "sessions_select_staff"
  on public.club_sessions for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'staff'
    )
  );

-- Sessions: staff update all (entry/exit scans)
create policy "sessions_update_staff"
  on public.club_sessions for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'staff'
    )
  );

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, birthdate, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.email, ''),
    nullif(new.raw_user_meta_data->>'birthdate', '')::date,
    coalesce(new.raw_user_meta_data->>'role', 'member')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Realtime for live entry/exit updates
alter publication supabase_realtime add table public.club_sessions;
