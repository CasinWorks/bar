-- Promote an existing user to admin (run in Supabase SQL Editor after they sign up)
-- Replace the email below:

update public.profiles
set role = 'admin'
where email = 'you@example.com';

-- Verify:
select id, email, name, role from public.profiles where role in ('admin', 'hr');
