-- Fix infinite recursion in RLS policies (staff checks querying profiles inside profiles policy)

create or replace function public.is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'staff'
  );
$$;

-- Profiles policies
drop policy if exists "profiles_select_staff" on public.profiles;
create policy "profiles_select_staff"
  on public.profiles for select
  using (public.is_staff());

-- Sessions policies
drop policy if exists "sessions_select_staff" on public.club_sessions;
create policy "sessions_select_staff"
  on public.club_sessions for select
  using (public.is_staff());

drop policy if exists "sessions_update_staff" on public.club_sessions;
create policy "sessions_update_staff"
  on public.club_sessions for update
  using (public.is_staff());
