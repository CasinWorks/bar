-- Branch catalog for member entry selection and admin-managed rollout.

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  sort_order int not null default 0,
  is_active boolean not null default true,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists branches_active_sort_idx
  on public.branches (is_active, sort_order, name);

create or replace function public.touch_branches_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_branches_updated_at on public.branches;
create trigger trg_branches_updated_at
  before update on public.branches
  for each row
  execute function public.touch_branches_updated_at();

alter table public.branches enable row level security;

drop policy if exists "branches_select_active" on public.branches;
create policy "branches_select_active"
  on public.branches for select
  using (is_active = true);

drop policy if exists "branches_admin_all" on public.branches;
create policy "branches_admin_all"
  on public.branches for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

insert into public.branches (slug, name, sort_order, is_active, is_default)
values
  ('cubao-branch', 'Cubao Branch', 1, true, true),
  ('tomas-morato', 'Tomas Morato', 2, true, false)
on conflict (slug) do update set
  name = excluded.name,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_default = excluded.is_default,
  updated_at = now();
