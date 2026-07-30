-- Drink orders must reach a terminal state in the DB, never only on a device.
--
-- Before this migration the only writer of `settled = true` was the guest's
-- phone (AppState._processDeliveredDrinkOrders). If the guest app was killed,
-- offline, or reinstalled — or if the bartender's SERVE write silently no-op'd —
-- the row stayed `pending` / `delivered + settled=false` forever and was pulled
-- back in by the next cloud hydration, so served drinks reappeared as
-- "Waiting at bar" after every reinstall.

alter table public.drink_orders
  add column if not exists settled_at timestamptz,
  add column if not exists closed_reason text;

create index if not exists drink_orders_open_member_idx
  on public.drink_orders (member_id, ordered_at desc)
  where settled = false;

create index if not exists drink_orders_open_session_idx
  on public.drink_orders (session_id)
  where settled = false;

-- Backfill terminal bookkeeping for rows already closed out.
update public.drink_orders
set settled_at = coalesce(settled_at, delivered_at, ordered_at)
where settled = true
  and settled_at is null;

-- ---------------------------------------------------------------------------
-- Staff serve: one authoritative transition, no reliance on the guest device.
-- ---------------------------------------------------------------------------
create or replace function public.staff_deliver_drink_order(p_order_id uuid)
returns public.drink_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.drink_orders;
  v_staff public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  if not public.is_staff_or_admin() then
    raise exception 'Staff only.';
  end if;

  select * into v_staff from public.profiles where id = auth.uid();

  select * into v_order
  from public.drink_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if v_order.status not in ('pending', 'preparing') then
    raise exception 'Order is no longer open.';
  end if;

  update public.drink_orders
  set status = 'delivered',
      delivered_at = now(),
      fulfilled_by_staff_id = auth.uid(),
      fulfilled_by_staff_name = coalesce(v_staff.name, fulfilled_by_staff_name)
  where id = p_order_id
  returning * into v_order;

  return v_order;
end;
$$;

revoke all on function public.staff_deliver_drink_order(uuid) from public;
grant execute on function public.staff_deliver_drink_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Staff cancel: terminal immediately, nothing to charge.
-- ---------------------------------------------------------------------------
create or replace function public.staff_cancel_drink_order(p_order_id uuid)
returns public.drink_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.drink_orders;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  if not public.is_staff_or_admin() then
    raise exception 'Staff only.';
  end if;

  select * into v_order
  from public.drink_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if v_order.status not in ('pending', 'preparing') then
    raise exception 'Order is no longer open.';
  end if;

  update public.drink_orders
  set status = 'cancelled',
      settled = true,
      settled_at = now(),
      closed_reason = 'staff_cancelled'
  where id = p_order_id
  returning * into v_order;

  return v_order;
end;
$$;

revoke all on function public.staff_cancel_drink_order(uuid) from public;
grant execute on function public.staff_cancel_drink_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Guest settlement: records why the order closed (paid, or owed at the bar).
-- ---------------------------------------------------------------------------
create or replace function public.settle_drink_order(
  p_order_id uuid,
  p_reason text default 'member_settled'
)
returns public.drink_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.drink_orders;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_order
  from public.drink_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if v_order.member_id <> auth.uid() and not public.is_staff_or_admin() then
    raise exception 'Not your order.';
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Only delivered orders can be settled.';
  end if;

  update public.drink_orders
  set settled = true,
      settled_at = coalesce(settled_at, now()),
      closed_reason = coalesce(closed_reason, nullif(trim(coalesce(p_reason, '')), ''))
  where id = p_order_id
  returning * into v_order;

  return v_order;
end;
$$;

revoke all on function public.settle_drink_order(uuid, text) from public;
grant execute on function public.settle_drink_order(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Safety net: close orders abandoned by a finished visit or by age.
--
-- A guest can only close their own rows; staff/admin may target any member.
-- ---------------------------------------------------------------------------
create or replace function public.close_stale_drink_orders(
  p_member_id uuid default null,
  p_max_age_minutes int default 120,
  p_delivered_grace_minutes int default 720
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member uuid;
  v_open_cutoff timestamptz;
  v_delivered_cutoff timestamptz;
  v_closed int := 0;
  v_settled int := 0;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  v_member := coalesce(p_member_id, auth.uid());
  if v_member <> auth.uid() and not public.is_staff_or_admin() then
    raise exception 'Not allowed to close other members'' orders.';
  end if;

  v_open_cutoff := now()
    - make_interval(mins => greatest(coalesce(p_max_age_minutes, 120), 1));
  v_delivered_cutoff := now()
    - make_interval(mins => greatest(coalesce(p_delivered_grace_minutes, 720), 1));

  -- Never served: nothing was consumed, so cancelling costs the guest nothing.
  with stale as (
    select o.id,
           case when s.phase = 'completed' then 'visit_completed' else 'expired' end as reason
    from public.drink_orders o
    left join public.club_sessions s on s.id = o.session_id
    where o.member_id = v_member
      and o.status in ('pending', 'preparing')
      and (s.phase = 'completed' or o.ordered_at < v_open_cutoff)
  )
  update public.drink_orders o
  set status = 'cancelled',
      settled = true,
      settled_at = now(),
      closed_reason = stale.reason
  from stale
  where o.id = stale.id;
  get diagnostics v_closed = row_count;

  -- Served but never settled. The guest device applies the charge, so this only
  -- fires once the grace window is gone — otherwise a phone that was asleep at
  -- serve time would get the drink for free.
  with unsettled as (
    select o.id
    from public.drink_orders o
    where o.member_id = v_member
      and o.status = 'delivered'
      and o.settled = false
      and coalesce(o.delivered_at, o.ordered_at) < v_delivered_cutoff
  )
  update public.drink_orders o
  set settled = true,
      settled_at = now(),
      closed_reason = coalesce(o.closed_reason, 'auto_settled_stale')
  from unsettled
  where o.id = unsettled.id;
  get diagnostics v_settled = row_count;

  return v_closed + v_settled;
end;
$$;

revoke all on function public.close_stale_drink_orders(uuid, int, int) from public;
grant execute on function public.close_stale_drink_orders(uuid, int, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Ending a visit closes its bar queue, whatever state the guest app is in.
--
-- Only never-served orders are cancelled here. Delivered rows keep their
-- unsettled flag so the guest device can still apply the charge; they are
-- closed by close_stale_drink_orders once the grace window expires.
-- ---------------------------------------------------------------------------
create or replace function public.close_drink_orders_for_finished_session()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.drink_orders
  set status = 'cancelled',
      settled = true,
      settled_at = now(),
      closed_reason = 'visit_completed'
  where session_id = new.id
    and status in ('pending', 'preparing');

  return new;
end;
$$;

drop trigger if exists close_drink_orders_on_session_complete on public.club_sessions;
create trigger close_drink_orders_on_session_complete
  after update of phase on public.club_sessions
  for each row
  when (new.phase = 'completed' and coalesce(old.phase, '') <> 'completed')
  execute function public.close_drink_orders_for_finished_session();

-- ---------------------------------------------------------------------------
-- One-off cleanup of rows already stuck by the old client-only settlement.
-- ---------------------------------------------------------------------------
update public.drink_orders o
set status = 'cancelled',
    settled = true,
    settled_at = now(),
    closed_reason = 'backfill_stale_pending'
from public.club_sessions s
where s.id = o.session_id
  and o.status in ('pending', 'preparing')
  and (s.phase = 'completed' or o.ordered_at < now() - interval '2 hours');

update public.drink_orders o
set settled = true,
    settled_at = now(),
    closed_reason = coalesce(o.closed_reason, 'backfill_auto_settled')
where o.status = 'delivered'
  and o.settled = false
  and coalesce(o.delivered_at, o.ordered_at) < now() - interval '12 hours';
