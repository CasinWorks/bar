-- Atomic wallet spends so client RMW + timer flushes cannot double-charge or undo spends.

create or replace function public.spend_time_balance(p_seconds int)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;
  if p_seconds is null or p_seconds <= 0 then
    raise exception 'Seconds must be positive.';
  end if;

  select * into v_row
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_row.time_balance_seconds, 0) < p_seconds then
    raise exception 'Not enough time balance.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - p_seconds
  where id = auth.uid()
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.spend_time_balance(int) from public;
grant execute on function public.spend_time_balance(int) to authenticated;

-- Relative timer sync — never absolute overwrite (avoids undoing RPC spends).
create or replace function public.apply_timer_debt(p_seconds int)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;
  if p_seconds is null or p_seconds <= 0 then
    select * into v_row from public.profiles where id = auth.uid();
    return v_row;
  end if;

  update public.profiles
  set time_balance_seconds = greatest(0, coalesce(time_balance_seconds, 0) - p_seconds)
  where id = auth.uid()
  returning * into v_row;

  if not found then
    raise exception 'Profile not found.';
  end if;

  return v_row;
end;
$$;

revoke all on function public.apply_timer_debt(int) from public;
grant execute on function public.apply_timer_debt(int) to authenticated;

-- Package drink allowance burn (profile + optional session).
create or replace function public.consume_included_drink(p_session_id uuid default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.profiles;
  v_remaining int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_row
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  v_remaining := coalesce(v_row.included_drinks_remaining, 0);
  if v_remaining < 1 then
    raise exception 'No package drinks remaining.';
  end if;

  update public.profiles
  set included_drinks_remaining = included_drinks_remaining - 1
  where id = auth.uid()
  returning * into v_row;

  if p_session_id is not null then
    update public.club_sessions
    set included_drinks_remaining = greatest(0, coalesce(included_drinks_remaining, 0) - 1)
    where id = p_session_id
      and member_id = auth.uid();
  end if;

  return v_row;
end;
$$;

revoke all on function public.consume_included_drink(uuid) from public;
grant execute on function public.consume_included_drink(uuid) to authenticated;

-- Atomic experience redeem: deduct minutes + log redemption when activity exists.
create or replace function public.redeem_venue_activity(
  p_activity_slug text,
  p_session_id uuid,
  p_minutes int default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activity public.venue_activities;
  v_minutes int;
  v_seconds int;
  v_row public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_activity
  from public.venue_activities
  where slug = p_activity_slug and active = true;

  if found then
    v_minutes := v_activity.time_cost_minutes;
  else
    if p_minutes is null or p_minutes <= 0 then
      raise exception 'Unknown activity.';
    end if;
    v_minutes := p_minutes;
  end if;

  v_seconds := v_minutes * 60;

  select * into v_row
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_row.time_balance_seconds, 0) < v_seconds then
    raise exception 'Not enough time balance.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - v_seconds
  where id = auth.uid()
  returning * into v_row;

  if found and v_activity.id is not null and p_session_id is not null then
    insert into public.activity_redemptions (
      session_id, member_id, activity_id, minutes_charged
    ) values (
      p_session_id, auth.uid(), v_activity.id, v_minutes
    );
  end if;

  return v_row;
end;
$$;

revoke all on function public.redeem_venue_activity(text, uuid, int) from public;
grant execute on function public.redeem_venue_activity(text, uuid, int) to authenticated;

-- Ensure seeded activities include VIP + VVIP naming used by the app.
insert into public.venue_activities (slug, name, time_cost_minutes, description, sort_order)
values
  ('vip-lounge', 'VIP Lounge', 30, 'Private lounge access', 1),
  ('vvip-room', 'VVIP Room', 60, 'Top-tier private room', 2),
  ('secret-room', 'Secret Room', 45, 'Members-only room', 3),
  ('photo-booth', 'Photo Booth', 5, 'Capture the night', 4),
  ('dj-meet', 'DJ Meet & Greet', 15, 'Meet the booth', 5),
  ('private-booth', 'Private Booth', 30, 'Reserved booth time', 6)
on conflict (slug) do update set
  name = excluded.name,
  time_cost_minutes = excluded.time_cost_minutes,
  description = excluded.description,
  active = true,
  sort_order = excluded.sort_order;
