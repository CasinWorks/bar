-- Prevent accidental demotion of founder/operator accounts.
-- Mobile upserts / metadata defaults must never wipe admin access.

create or replace function public.protect_super_admin_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(old.email, new.email, '')) in (
    'christianjoshuacasin@gmail.com'
  ) then
    if new.role is distinct from 'admin' then
      new.role := 'admin';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_super_admin_role on public.profiles;
create trigger trg_protect_super_admin_role
  before update on public.profiles
  for each row
  execute function public.protect_super_admin_role();

-- Heal immediately if already demoted
update public.profiles
set role = 'admin'
where lower(email) in ('christianjoshuacasin@gmail.com')
  and role is distinct from 'admin';
