-- Tip a specific staff / bartender (NFC-style tip pad)

-- Allow tip_staff kind on transfers
alter table public.time_transfers
  drop constraint if exists time_transfers_kind_check;

alter table public.time_transfers
  add constraint time_transfers_kind_check
  check (kind in ('toast', 'tip_house', 'tip_staff'));

-- Members can resolve staff tip pads by id (needed to show name after scan)
drop policy if exists "profiles_select_staff_public" on public.profiles;
create policy "profiles_select_staff_public"
  on public.profiles for select
  using (role = 'staff');

-- Tip a bartender: move seconds from guest wallet → staff wallet
create or replace function public.tip_bartender(
  p_staff_id uuid,
  p_seconds int,
  p_message text default null
)
returns public.time_transfers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
  v_from_name text;
  v_to_name text;
  v_to_role text;
  v_row public.time_transfers;
begin
  if p_seconds < 60 then
    raise exception 'Minimum tip is 1 minute.';
  end if;
  if p_seconds > 3600 then
    raise exception 'Maximum tip is 60 minutes.';
  end if;
  if p_staff_id = auth.uid() then
    raise exception 'You cannot tip yourself.';
  end if;

  select time_balance_seconds, name
    into v_balance, v_from_name
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_balance, 0) < p_seconds then
    raise exception 'Not enough time balance to tip.';
  end if;

  select name, role
    into v_to_name, v_to_role
  from public.profiles
  where id = p_staff_id
  for update;

  if not found or v_to_role <> 'staff' then
    raise exception 'Bartender tip pad not found.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - p_seconds
  where id = auth.uid();

  update public.profiles
  set time_balance_seconds = time_balance_seconds + p_seconds
  where id = p_staff_id;

  insert into public.time_transfers (
    from_member_id,
    from_member_name,
    to_member_id,
    to_member_name,
    seconds,
    kind,
    message,
    status,
    claimed_at
  ) values (
    auth.uid(),
    coalesce(v_from_name, ''),
    p_staff_id,
    coalesce(v_to_name, ''),
    p_seconds,
    'tip_staff',
    p_message,
    'completed',
    now()
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.tip_bartender(uuid, int, text) to authenticated;

-- Staff: see tips received
create policy "transfers_select_staff_received"
  on public.time_transfers for select
  using (
    to_member_id = auth.uid()
    or public.is_staff()
  );
