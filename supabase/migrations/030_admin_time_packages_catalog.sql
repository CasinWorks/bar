-- Admin-managed entry package catalog.
-- Extends public.time_packages (created in 020) with display fields + write RLS.

alter table public.time_packages
  add column if not exists tagline text,
  add column if not exists popular boolean not null default false,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists time_packages_active_sort_idx
  on public.time_packages (active, sort_order, name);

create or replace function public.touch_time_packages_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_time_packages_updated_at on public.time_packages;
create trigger trg_time_packages_updated_at
  before update on public.time_packages
  for each row
  execute function public.touch_time_packages_updated_at();

-- Seed defaults if missing; do not overwrite admin-edited pricing/catalog fields.
insert into public.time_packages (
  slug, name, price_peso, duration_minutes, included_drinks, target_guest, tagline, popular, sort_order, active
)
values
  ('quick-escape', 'Quick Escape', 699, 90, 2, 'After-work crowd', 'Your time starts now.', false, 1, true),
  ('standard-night', 'Standard Night', 999, 180, 4, 'Most guests', 'Every second counts.', true, 2, true),
  ('after-hours', 'After Hours', 1299, 240, 5, 'Late-night / weekend', 'Extend your time.', false, 3, true),
  ('unlimited', 'Unlimited', 1799, null, null, 'VIP / Members', 'Invest your time wisely.', false, 4, true)
on conflict (slug) do update set
  tagline = coalesce(public.time_packages.tagline, excluded.tagline),
  popular = public.time_packages.popular or excluded.popular,
  updated_at = now();

-- Members/anon: active packages only. Admins/HR: full catalog via service role or RLS.
drop policy if exists "time_packages_read_all" on public.time_packages;
drop policy if exists "time_packages_select_active_or_admin" on public.time_packages;
create policy "time_packages_select_active_or_admin"
  on public.time_packages for select
  using (active = true or public.is_admin_or_hr());

drop policy if exists "time_packages_admin_write" on public.time_packages;
create policy "time_packages_admin_write"
  on public.time_packages for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());
