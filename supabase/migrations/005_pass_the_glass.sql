-- Pass the Glass: tip / share club time between members

create table if not exists public.time_transfers (
  id uuid primary key default gen_random_uuid(),
  from_member_id uuid not null references public.profiles(id) on delete cascade,
  from_member_name text not null default '',
  to_member_id uuid references public.profiles(id) on delete set null,
  to_member_name text,
  seconds int not null check (seconds > 0),
  kind text not null check (kind in ('toast', 'tip_house')),
  code text unique,
  message text,
  status text not null default 'pending'
    check (status in ('pending', 'claimed', 'completed')),
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);

create index if not exists time_transfers_code_idx on public.time_transfers (code)
  where code is not null;
create index if not exists time_transfers_from_idx on public.time_transfers (from_member_id);
create index if not exists time_transfers_status_idx on public.time_transfers (status);

alter table public.time_transfers enable row level security;

create policy "transfers_select_own"
  on public.time_transfers for select
  using (
    from_member_id = auth.uid()
    or to_member_id = auth.uid()
  );

create policy "transfers_insert_own"
  on public.time_transfers for insert
  with check (from_member_id = auth.uid());

-- Tip the house: deduct wallet time + record gift (staff / house gratitude)
create or replace function public.tip_the_house(
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
  v_name text;
  v_row public.time_transfers;
begin
  if p_seconds < 60 then
    raise exception 'Minimum tip is 1 minute.';
  end if;

  select time_balance_seconds, name
    into v_balance, v_name
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_balance, 0) < p_seconds then
    raise exception 'Not enough time balance to tip.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - p_seconds
  where id = auth.uid();

  insert into public.time_transfers (
    from_member_id, from_member_name, seconds, kind, message, status
  ) values (
    auth.uid(), coalesce(v_name, ''), p_seconds, 'tip_house', p_message, 'completed'
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Raise a Toast: create claimable code; caller has already reserved the seconds
-- by deducting session or wallet on the client, then calling this with confirmation.
-- Safer path: lock seconds from wallet here.
create or replace function public.raise_a_toast(
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
  v_name text;
  v_code text;
  v_row public.time_transfers;
  v_attempt int := 0;
begin
  if p_seconds < 60 then
    raise exception 'Minimum toast is 1 minute.';
  end if;
  if p_seconds > 3600 then
    raise exception 'Maximum toast is 60 minutes.';
  end if;

  select time_balance_seconds, name
    into v_balance, v_name
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_balance, 0) < p_seconds then
    raise exception 'Not enough time balance for this toast.';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := 'GLASS-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
    exit when not exists (
      select 1 from public.time_transfers where code = v_code and status = 'pending'
    );
    if v_attempt > 8 then
      raise exception 'Could not generate a unique toast code.';
    end if;
  end loop;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - p_seconds
  where id = auth.uid();

  insert into public.time_transfers (
    from_member_id, from_member_name, seconds, kind, code, message, status
  ) values (
    auth.uid(), coalesce(v_name, ''), p_seconds, 'toast', v_code, p_message, 'pending'
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Claim a raised toast by glass code → add minutes to claimant wallet
create or replace function public.claim_a_toast(p_code text)
returns public.time_transfers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.time_transfers;
  v_name text;
  v_normalized text;
begin
  v_normalized := upper(trim(p_code));

  select * into v_row
  from public.time_transfers
  where code = v_normalized
    and kind = 'toast'
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Toast not found or already claimed.';
  end if;

  if v_row.from_member_id = auth.uid() then
    raise exception 'You cannot claim your own toast.';
  end if;

  select name into v_name from public.profiles where id = auth.uid();

  update public.profiles
  set time_balance_seconds = time_balance_seconds + v_row.seconds
  where id = auth.uid();

  update public.time_transfers
  set status = 'claimed',
      to_member_id = auth.uid(),
      to_member_name = coalesce(v_name, ''),
      claimed_at = now()
  where id = v_row.id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.tip_the_house(int, text) to authenticated;
grant execute on function public.raise_a_toast(int, text) to authenticated;
grant execute on function public.claim_a_toast(text) to authenticated;
