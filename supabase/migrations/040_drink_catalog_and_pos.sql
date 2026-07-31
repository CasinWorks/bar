-- Drink catalog (admin inventory) + bartender POS payment tickets.
-- Guest pays by scanning a short-lived QR shown on the staff phone.

-- ---------------------------------------------------------------------------
-- 1. Catalog
-- ---------------------------------------------------------------------------

create table if not exists public.drink_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  kind text not null default 'premium'
    check (kind in ('standard', 'premium')),
  time_cost_seconds int not null default 0 check (time_cost_seconds >= 0),
  price_peso int check (price_peso is null or price_peso >= 0),
  category text not null default 'spirits',
  description text not null default '',
  flavor text not null default '',
  abv text not null default '',
  badge text,
  ingredients text[] not null default '{}',
  bartender_quote text not null default '',
  image_color_start bigint not null default 4292462342, -- 0xFFD97706
  image_color_end bigint not null default 4286051599, -- 0xFF78350F
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists drink_catalog_active_sort_idx
  on public.drink_catalog (active, sort_order, name);

create or replace function public.touch_drink_catalog_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_drink_catalog_updated_at on public.drink_catalog;
create trigger trg_drink_catalog_updated_at
  before update on public.drink_catalog
  for each row
  execute function public.touch_drink_catalog_updated_at();

alter table public.drink_catalog enable row level security;

drop policy if exists "drink_catalog_select_active" on public.drink_catalog;
create policy "drink_catalog_select_active"
  on public.drink_catalog for select
  using (active = true or public.is_admin_or_hr() or public.is_staff_or_admin());

drop policy if exists "drink_catalog_admin_all" on public.drink_catalog;
create policy "drink_catalog_admin_all"
  on public.drink_catalog for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

-- Seed from the historical in-app mock menu (idempotent by slug).
insert into public.drink_catalog (
  slug, name, kind, time_cost_seconds, price_peso, category, description,
  flavor, abv, badge, ingredients, bartender_quote,
  image_color_start, image_color_end, active, sort_order
) values
  (
    'tigers-eye-old-fashioned',
    'Tiger''s Eye Old Fashioned',
    'premium',
    900,
    480,
    'spirits',
    'Single-barrel bourbon infused with local toasted pandan leaves, aromatic bitters, wild orange oil, and a hand-carved ice sphere.',
    'Rich, Toasty, Citrusy',
    '18% ABV',
    'Signature',
    array['Pandan-infused Bourbon','Angostura Bitters','Orange Oil Blend','Dehydrated Orange Wheel','Clear Ice Sphere'],
    '"Watch the gold leaf catch the light. Sip slow, let the smoke settle."',
    4292462342, -- 0xFFD97706
    4286051599, -- 0xFF78350F
    true,
    1
  ),
  (
    'manila-dusk-sour',
    'Manila Dusk Sour',
    'premium',
    720,
    450,
    'spirits',
    'Premium Lambanog combined with fresh calamansi juice, butterfly pea flower syrup, wild forest honey, and egg white foam.',
    'Earthy, Sweet & Sour',
    '14% ABV',
    'Local Favorite',
    array['Premium Lambanog','Fresh Calamansi','Butterfly Pea Extract','Wild Forest Honey','Silky Foam topping'],
    '"Like a Manila sunset, it shifts from deep purple to sunset amber as you sip."',
    4287861738, -- 0xFF9333EA
    4286051599, -- 0xFF78350F
    true,
    2
  ),
  (
    'velvet-midnight',
    'The Velvet Midnight',
    'premium',
    600,
    520,
    'spirits',
    'Spiced dark rum mixed with cold brew coffee, local tablea cacao reduction, cardamom pods, and toasted salted coconut flakes.',
    'Bold, Bitter-sweet, Spiced',
    '15% ABV',
    'Bartender''s Choice',
    array['Spiced Dark Rum','Cold Brew Coffee Liqueur','Tablea Chocolate Syrup','Cardamom Essence','Toasted Coconut flakes'],
    '"For those who find their rhythm only after the acoustic guitar fades."',
    4280035850, -- 0xFF1A0A0A
    4283236352, -- 0xFF4D0000
    true,
    3
  ),
  (
    'jazz-age-highball',
    'Jazz Age Highball',
    'standard',
    0,
    null,
    'spirits',
    'Blended Japanese whiskey, clear carbonated jasmine green tea, fresh ginger root infusion, and a tall block of crystal-clear ice.',
    'Crisp, Effervescent, Herbaceous',
    '11% ABV',
    'Package',
    array['Suntory Toki Whiskey','Jasmine Green Tea Soda','Fresh Ginger Extract','Lemon Zest Twist'],
    '"Clean, light, and sharp enough to keep your mind active for the vinyl DJ set."',
    4291084377, -- 0xFFC5A059
    4280688640, -- 0xFF2A2000
    true,
    4
  ),
  (
    'san-miguel-tiger-draft',
    'San Miguel Tiger Draft',
    'standard',
    300,
    null,
    'beer',
    'An exclusive draft lager crafted specifically for The Blind Tiger. Crisp, served sub-zero in an amber stoneware stein.',
    'Crisp, Refreshing, Malt-forward',
    '5.0% ABV',
    'Package',
    array['Local Premium Malt','Centennial Hops','Filtered Spring Water','Tiger Oak Infusion'],
    '"Pouring continuously from midnight till the closing bell."',
    4291422724, -- 0xFFCA8A04
    4286051599, -- 0xFF78350F
    true,
    5
  )
on conflict (slug) do update set
  name = excluded.name,
  kind = excluded.kind,
  time_cost_seconds = excluded.time_cost_seconds,
  price_peso = excluded.price_peso,
  category = excluded.category,
  description = excluded.description,
  flavor = excluded.flavor,
  abv = excluded.abv,
  badge = excluded.badge,
  ingredients = excluded.ingredients,
  bartender_quote = excluded.bartender_quote,
  image_color_start = excluded.image_color_start,
  image_color_end = excluded.image_color_end,
  sort_order = excluded.sort_order,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 2. POS payment tickets (bartender cart → QR → guest pays)
-- ---------------------------------------------------------------------------

create table if not exists public.drink_pos_tickets (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.profiles (id),
  staff_name text not null,
  items jsonb not null,
  -- Snapshot totals for the QR screen (not the authoritative charge path).
  line_count int not null default 0 check (line_count > 0),
  status text not null default 'awaiting_payment'
    check (status in ('awaiting_payment', 'paid', 'cancelled', 'expired')),
  paid_by_member_id uuid references public.profiles (id),
  paid_by_member_name text,
  paid_at timestamptz,
  balance_before int,
  balance_after int,
  package_drinks_before int,
  package_drinks_after int,
  charged_seconds int not null default 0,
  charge_summary jsonb,
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists drink_pos_tickets_staff_status_idx
  on public.drink_pos_tickets (staff_id, status, created_at desc);

create index if not exists drink_pos_tickets_status_idx
  on public.drink_pos_tickets (status, expires_at);

create or replace function public.touch_drink_pos_tickets_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_drink_pos_tickets_updated_at on public.drink_pos_tickets;
create trigger trg_drink_pos_tickets_updated_at
  before update on public.drink_pos_tickets
  for each row
  execute function public.touch_drink_pos_tickets_updated_at();

alter table public.drink_pos_tickets enable row level security;

drop policy if exists "drink_pos_tickets_staff_select" on public.drink_pos_tickets;
create policy "drink_pos_tickets_staff_select"
  on public.drink_pos_tickets for select
  using (
    public.is_staff_or_admin()
    or paid_by_member_id = auth.uid()
  );

-- Mutations go through security-definer RPCs only.
drop policy if exists "drink_pos_tickets_no_direct_write" on public.drink_pos_tickets;

do $$
begin
  alter publication supabase_realtime add table public.drink_pos_tickets;
exception
  when duplicate_object then null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Staff creates a POS ticket from cart lines
-- ---------------------------------------------------------------------------

create or replace function public.staff_create_drink_pos_ticket(p_items jsonb)
returns public.drink_pos_tickets
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_staff public.profiles;
  v_item jsonb;
  v_slug text;
  v_qty int;
  v_drink public.drink_catalog;
  v_normalized jsonb := '[]'::jsonb;
  v_line_count int := 0;
  v_row public.drink_pos_tickets;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;
  if not public.is_staff_or_admin() then
    raise exception 'Staff only.';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Cart is empty.';
  end if;

  select * into v_staff from public.profiles where id = auth.uid();
  if not found then
    raise exception 'Profile not found.';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_slug := lower(trim(coalesce(v_item->>'slug', v_item->>'drink_id', '')));
    v_qty := greatest(1, least(20, coalesce((v_item->>'quantity')::int, 1)));
    if v_slug = '' then
      raise exception 'Each cart line needs a drink slug.';
    end if;

    select * into v_drink
    from public.drink_catalog
    where slug = v_slug and active = true;

    if not found then
      raise exception 'Drink "%" is not on the menu.', v_slug;
    end if;

    v_normalized := v_normalized || jsonb_build_array(
      jsonb_build_object(
        'slug', v_drink.slug,
        'name', v_drink.name,
        'kind', v_drink.kind,
        'time_cost_seconds', v_drink.time_cost_seconds,
        'quantity', v_qty
      )
    );
    v_line_count := v_line_count + v_qty;
  end loop;

  insert into public.drink_pos_tickets (
    staff_id,
    staff_name,
    items,
    line_count,
    status,
    expires_at
  ) values (
    v_staff.id,
    coalesce(nullif(trim(v_staff.name), ''), 'Bartender'),
    v_normalized,
    v_line_count,
    'awaiting_payment',
    now() + interval '10 minutes'
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.staff_create_drink_pos_ticket(jsonb) from public;
grant execute on function public.staff_create_drink_pos_ticket(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Guest pays ticket by scanning QR (charges wallet / package drinks)
-- ---------------------------------------------------------------------------

create or replace function public.pay_drink_pos_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_ticket public.drink_pos_tickets;
  v_member public.profiles;
  v_session public.club_sessions;
  v_item jsonb;
  v_qty int;
  v_unit int;
  v_kind text;
  v_cost int;
  v_name text;
  v_slug text;
  v_charge_source text;
  v_charged_seconds int := 0;
  v_package_used int := 0;
  v_balance_before int;
  v_package_before int;
  v_order_id uuid;
  v_summary jsonb := '[]'::jsonb;
  v_drink_names text := '';
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_member
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if coalesce(v_member.is_banned, false) then
    raise exception 'Account suspended.';
  end if;

  select * into v_session
  from public.club_sessions
  where member_id = auth.uid()
    and exited_at is null
    and phase in ('inside_club', 'awaiting_exit_scan')
  order by entered_at desc nulls last, created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Scan in at the door before paying at the bar.';
  end if;

  select * into v_ticket
  from public.drink_pos_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'Payment QR not found.';
  end if;

  if v_ticket.status = 'paid' then
    if v_ticket.paid_by_member_id = auth.uid() then
      return jsonb_build_object(
        'ok', true,
        'already_paid', true,
        'ticket_id', v_ticket.id,
        'drink_names', coalesce(v_ticket.charge_summary->>'drink_names', 'Drinks'),
        'charged_seconds', coalesce(v_ticket.charged_seconds, 0),
        'balance_before', v_ticket.balance_before,
        'balance_after', v_ticket.balance_after,
        'package_drinks_before', v_ticket.package_drinks_before,
        'package_drinks_after', v_ticket.package_drinks_after,
        'staff_name', v_ticket.staff_name,
        'charge_summary', v_ticket.charge_summary
      );
    end if;
    raise exception 'This order was already paid.';
  end if;

  if v_ticket.status <> 'awaiting_payment' then
    raise exception 'This payment QR is no longer valid.';
  end if;

  if v_ticket.expires_at <= now() then
    update public.drink_pos_tickets
    set status = 'expired'
    where id = v_ticket.id;
    raise exception 'Payment QR expired — ask the bartender to start a new order.';
  end if;

  if v_ticket.staff_id = auth.uid() then
    raise exception 'Guests pay this QR — staff cannot scan their own pad.';
  end if;

  v_balance_before := coalesce(v_member.time_balance_seconds, 0);
  v_package_before := coalesce(v_member.included_drinks_remaining, 0);

  for v_item in select * from jsonb_array_elements(v_ticket.items)
  loop
    v_slug := coalesce(v_item->>'slug', '');
    v_name := coalesce(v_item->>'name', 'Drink');
    v_kind := coalesce(v_item->>'kind', 'premium');
    v_cost := greatest(0, coalesce((v_item->>'time_cost_seconds')::int, 0));
    v_qty := greatest(1, coalesce((v_item->>'quantity')::int, 1));

    for v_unit in 1..v_qty
    loop
      if v_kind = 'standard' and coalesce(v_member.included_drinks_remaining, 0) > 0 then
        v_charge_source := 'packageAllowance';
        update public.profiles
        set included_drinks_remaining = included_drinks_remaining - 1
        where id = v_member.id
          and included_drinks_remaining >= 1
        returning * into v_member;

        if not found then
          raise exception 'No package drinks remaining.';
        end if;

        update public.club_sessions
        set included_drinks_remaining = greatest(0, coalesce(included_drinks_remaining, 0) - 1),
            drinks_ordered = coalesce(drinks_ordered, 0) + 1
        where id = v_session.id;

        v_package_used := v_package_used + 1;
        v_cost := 0;
      else
        v_charge_source := 'personalTime';
        if v_cost <= 0 then
          -- Standard with no allowance and no time price → refuse rather than free pour.
          if v_kind = 'standard' then
            raise exception
              'No package drinks left for "%". Ask the bartender to ring a timed drink.',
              v_name;
          end if;
          raise exception 'Drink "%" has no time price configured.', v_name;
        end if;

        if coalesce(v_member.time_balance_seconds, 0) < v_cost then
          raise exception 'Not enough time balance for "%".', v_name;
        end if;

        update public.profiles
        set time_balance_seconds = time_balance_seconds - v_cost
        where id = v_member.id
          and time_balance_seconds >= v_cost
        returning * into v_member;

        if not found then
          raise exception 'Not enough time balance for "%".', v_name;
        end if;

        update public.club_sessions
        set drinks_ordered = coalesce(drinks_ordered, 0) + 1
        where id = v_session.id;

        v_charged_seconds := v_charged_seconds + v_cost;
      end if;

      v_order_id := gen_random_uuid();
      insert into public.drink_orders (
        id,
        session_id,
        member_id,
        member_name,
        drink_id,
        drink_name,
        charge_source,
        cost_seconds,
        pay_with_cash,
        status,
        ordered_at,
        preparing_at,
        delivered_at,
        fulfilled_by_staff_id,
        fulfilled_by_staff_name,
        settled,
        settled_at,
        closed_reason
      ) values (
        v_order_id,
        v_session.id,
        v_member.id,
        coalesce(nullif(trim(v_member.name), ''), 'Guest'),
        v_slug,
        v_name,
        v_charge_source,
        v_cost,
        false,
        'delivered',
        now(),
        now(),
        now(),
        v_ticket.staff_id,
        v_ticket.staff_name,
        true,
        now(),
        'pos_paid'
      );

      v_summary := v_summary || jsonb_build_array(
        jsonb_build_object(
          'order_id', v_order_id,
          'name', v_name,
          'charge_source', v_charge_source,
          'cost_seconds', v_cost
        )
      );

      if v_drink_names = '' then
        v_drink_names := v_name;
      else
        v_drink_names := v_drink_names || ', ' || v_name;
      end if;
    end loop;
  end loop;

  update public.drink_pos_tickets
  set
    status = 'paid',
    paid_by_member_id = v_member.id,
    paid_by_member_name = coalesce(nullif(trim(v_member.name), ''), 'Guest'),
    paid_at = now(),
    balance_before = v_balance_before,
    balance_after = coalesce(v_member.time_balance_seconds, 0),
    package_drinks_before = v_package_before,
    package_drinks_after = coalesce(v_member.included_drinks_remaining, 0),
    charged_seconds = v_charged_seconds,
    charge_summary = jsonb_build_object(
      'lines', v_summary,
      'drink_names', v_drink_names,
      'package_drinks_used', v_package_used
    )
  where id = v_ticket.id
  returning * into v_ticket;

  return jsonb_build_object(
    'ok', true,
    'already_paid', false,
    'ticket_id', v_ticket.id,
    'drink_names', v_drink_names,
    'charged_seconds', v_charged_seconds,
    'balance_before', v_balance_before,
    'balance_after', coalesce(v_member.time_balance_seconds, 0),
    'package_drinks_before', v_package_before,
    'package_drinks_after', coalesce(v_member.included_drinks_remaining, 0),
    'package_drinks_used', v_package_used,
    'staff_name', v_ticket.staff_name,
    'charge_summary', v_ticket.charge_summary
  );
end;
$$;

revoke all on function public.pay_drink_pos_ticket(uuid) from public;
grant execute on function public.pay_drink_pos_ticket(uuid) to authenticated;

create or replace function public.staff_cancel_drink_pos_ticket(p_ticket_id uuid)
returns public.drink_pos_tickets
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.drink_pos_tickets;
begin
  if auth.uid() is null or not public.is_staff_or_admin() then
    raise exception 'Staff only.';
  end if;

  update public.drink_pos_tickets
  set status = 'cancelled'
  where id = p_ticket_id
    and staff_id = auth.uid()
    and status = 'awaiting_payment'
  returning * into v_row;

  if not found then
    raise exception 'Ticket not found or already closed.';
  end if;

  return v_row;
end;
$$;

revoke all on function public.staff_cancel_drink_pos_ticket(uuid) from public;
grant execute on function public.staff_cancel_drink_pos_ticket(uuid) to authenticated;
