-- Guest drink orders — synced across member + bartender phones (realtime bar queue).

create table if not exists public.drink_orders (
  id uuid primary key,
  session_id uuid not null references public.club_sessions(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  member_name text not null,
  drink_id text not null,
  drink_name text not null,
  charge_source text not null check (
    charge_source in ('personalTime', 'vipRoomTab', 'packageAllowance', 'cashAtBar')
  ),
  cost_seconds int not null default 0,
  pay_with_cash boolean not null default false,
  status text not null default 'pending' check (
    status in ('pending', 'preparing', 'delivered', 'cancelled')
  ),
  ordered_at timestamptz not null default now(),
  preparing_at timestamptz,
  delivered_at timestamptz,
  fulfilled_by_staff_id uuid references public.profiles(id),
  fulfilled_by_staff_name text,
  vip_room_name text,
  settled boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists drink_orders_status_idx on public.drink_orders (status);
create index if not exists drink_orders_member_id_idx on public.drink_orders (member_id);
create index if not exists drink_orders_session_id_idx on public.drink_orders (session_id);

alter table public.drink_orders enable row level security;

-- Members insert their own orders
create policy "drink_orders_insert_member"
  on public.drink_orders for insert
  with check (member_id = auth.uid());

-- Members read their own orders
create policy "drink_orders_select_member"
  on public.drink_orders for select
  using (member_id = auth.uid());

-- Members update their own orders (settled flag after serve)
create policy "drink_orders_update_member"
  on public.drink_orders for update
  using (member_id = auth.uid())
  with check (member_id = auth.uid());

-- Staff read all orders (bar queue)
create policy "drink_orders_select_staff"
  on public.drink_orders for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'staff'
    )
  );

-- Staff update all orders (pour / serve / cancel)
create policy "drink_orders_update_staff"
  on public.drink_orders for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'staff'
    )
  );

alter publication supabase_realtime add table public.drink_orders;
