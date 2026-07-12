-- Void / reverse mistaken cash desk time loads

alter table public.time_loads
  add column if not exists status text not null default 'posted'
    check (status in ('posted', 'voided')),
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.profiles(id),
  add column if not exists void_reason text;

update public.time_loads set status = 'posted' where status is null;

create index if not exists time_loads_status_idx on public.time_loads (status);

create or replace function public.admin_void_time_load(
  p_load_id uuid,
  p_reason text default null,
  p_admin_id uuid default null
)
returns public.time_loads
language plpgsql
security definer
set search_path = public
as $$
declare
  v_load public.time_loads;
  v_admin uuid;
  v_balance int;
begin
  select * into v_load
  from public.time_loads
  where id = p_load_id
  for update;

  if not found then
    raise exception 'Load not found.';
  end if;

  if v_load.status = 'voided' then
    raise exception 'This load was already voided.';
  end if;

  v_admin := coalesce(p_admin_id, auth.uid());
  if v_admin is null then
    raise exception 'Admin identity required.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_admin and role in ('admin', 'hr')
  ) then
    raise exception 'Not authorized to void loads.';
  end if;

  select time_balance_seconds into v_balance
  from public.profiles
  where id = v_load.member_id
  for update;

  if v_balance < v_load.seconds_loaded then
    raise exception
      'Cannot void — guest only has % min left but this load was % min. They may have already spent it.',
      (v_balance / 60),
      (v_load.seconds_loaded / 60);
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - v_load.seconds_loaded
  where id = v_load.member_id;

  update public.time_loads
  set
    status = 'voided',
    voided_at = now(),
    voided_by = v_admin,
    void_reason = nullif(trim(p_reason), '')
  where id = p_load_id
  returning * into v_load;

  return v_load;
end;
$$;

grant execute on function public.admin_void_time_load(uuid, text, uuid) to authenticated;
grant execute on function public.admin_void_time_load(uuid, text, uuid) to service_role;
