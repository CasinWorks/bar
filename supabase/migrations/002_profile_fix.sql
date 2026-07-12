-- Fix: allow users to create their own profile if trigger missed them
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Backfill profiles for auth users created before the trigger existed
insert into public.profiles (id, name, email, birthdate, role)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'name', ''),
  coalesce(u.email, ''),
  nullif(u.raw_user_meta_data->>'birthdate', '')::date,
  coalesce(u.raw_user_meta_data->>'role', 'member')
from auth.users u
where not exists (
  select 1 from public.profiles p where p.id = u.id
);
