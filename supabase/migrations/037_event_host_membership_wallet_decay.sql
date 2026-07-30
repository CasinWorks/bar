-- Event host membership, shareable host invites, and passive event-wallet decay.
--
-- Gaps this closes
-- ----------------
-- 1) Hosts lived only on club_events.host_id — never as event_guests — so
--    get_active_event_for_member / drink wallet charging never treated them as
--    part of the party.
-- 2) Hosts had no RPC to mint guest invites after approval (admin guest list
--    was the only path).
-- 3) Event wallet_seconds only moved on drink charges — never ticked down once
--    the event window started.

-- ---------------------------------------------------------------------------
-- Passive: last time passive decay was applied (authoritative shared timer)
-- ---------------------------------------------------------------------------

alter table public.club_events
  add column if not exists wallet_last_decayed_at timestamptz;

comment on column public.club_events.wallet_last_decayed_at is
  'Wall-clock stamp of the last passive 1:1 event-wallet decay tick while live.';

-- Allow shared-timer decay ledger rows.
alter table public.event_wallet_transactions
  drop constraint if exists event_wallet_transactions_kind_check;
alter table public.event_wallet_transactions
  add constraint event_wallet_transactions_kind_check
  check (
    kind in (
      'seed',
      'extension',
      'drink_charge',
      'admin_adjustment',
      'refund',
      'passive_decay'
    )
  );

-- ---------------------------------------------------------------------------
-- Passive: apply passive decay for one or all live approved events
-- ---------------------------------------------------------------------------

create or replace function public.apply_event_wallet_passive_decay(
  p_event_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.club_events%rowtype;
  v_elapsed int;
  v_deduct int;
  v_anchor timestamptz;
begin
  for v_row in
    select *
    from public.club_events ce
    where coalesce(ce.approval_status, 'pending_review') = 'approved'
      and coalesce(ce.status, 'scheduled') <> 'cancelled'
      and public.is_event_active(ce.starts_at, ce.ends_at)
      and ce.wallet_seconds > 0
      and (p_event_id is null or ce.id = p_event_id)
    for update
  loop
    v_anchor := coalesce(
      v_row.wallet_last_decayed_at,
      v_row.starts_at,
      now()
    );
    -- Never decay before the event actually started.
    if v_anchor < v_row.starts_at then
      v_anchor := v_row.starts_at;
    end if;
    if v_anchor > now() then
      -- Clock skew / future start — just stamp and wait.
      update public.club_events
      set wallet_last_decayed_at = v_anchor
      where id = v_row.id
        and wallet_last_decayed_at is distinct from v_anchor;
      continue;
    end if;

    v_elapsed := greatest(
      0,
      floor(extract(epoch from (now() - v_anchor)))::int
    );
    if v_elapsed <= 0 then
      if v_row.wallet_last_decayed_at is null then
        update public.club_events
        set wallet_last_decayed_at = v_anchor
        where id = v_row.id;
      end if;
      continue;
    end if;

    v_deduct := least(v_elapsed, v_row.wallet_seconds);
    if v_deduct <= 0 then
      continue;
    end if;

    update public.club_events
    set wallet_seconds = wallet_seconds - v_deduct,
        wallet_consumed_seconds = wallet_consumed_seconds + v_deduct,
        wallet_last_decayed_at = v_anchor + make_interval(secs => v_deduct)
    where id = v_row.id;

    insert into public.event_wallet_transactions (
      event_id,
      actor_id,
      kind,
      seconds_delta,
      balance_after_seconds,
      note,
      metadata
    )
    select
      v_row.id,
      v_row.host_id,
      'passive_decay',
      -v_deduct,
      ce.wallet_seconds,
      'Event wallet decayed while live.',
      jsonb_build_object('elapsed_seconds', v_elapsed, 'deducted_seconds', v_deduct)
    from public.club_events ce
    where ce.id = v_row.id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ensure the host is a first-class party member (invite + guest row)
-- ---------------------------------------------------------------------------

create or replace function public.ensure_host_event_membership(
  p_event_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events%rowtype;
  v_profile public.profiles%rowtype;
  v_host_id uuid;
  v_name text;
  v_email text;
  v_phone text;
  v_identity text;
  v_invite public.event_invites%rowtype;
  v_guest public.event_guests%rowtype;
begin
  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Hosted event not found.';
  end if;

  v_host_id := coalesce(v_event.host_id, v_event.requested_by);
  if v_host_id is null then
    raise exception 'Event has no host.';
  end if;

  select *
    into v_profile
  from public.profiles
  where id = v_host_id;

  v_name := coalesce(
    nullif(trim(coalesce(v_event.host_name, '')), ''),
    nullif(trim(coalesce(v_profile.name, '')), ''),
    'Host'
  );
  v_email := lower(nullif(trim(coalesce(
    nullif(trim(coalesce(v_event.host_email, '')), ''),
    coalesce(v_profile.email, '')
  )), ''));
  v_phone := nullif(trim(coalesce(
    nullif(trim(coalesce(v_event.host_phone, '')), ''),
    coalesce(v_profile.phone, '')
  )), '');
  v_identity := public.event_guest_identity_key(v_name, v_email, v_phone);

  -- Prefer an existing guest row for this host member.
  select *
    into v_guest
  from public.event_guests
  where event_id = p_event_id
    and member_id = v_host_id
  limit 1;

  if found then
    return v_guest;
  end if;

  insert into public.event_invites (
    event_id,
    guest_name,
    guest_email,
    guest_phone,
    guest_identity_key,
    invite_code,
    invite_token,
    status,
    created_by,
    accepted_by,
    accepted_at,
    last_sent_at,
    notes,
    metadata
  ) values (
    p_event_id,
    v_name,
    v_email,
    v_phone,
    v_identity,
    public.generate_event_invite_code(),
    public.generate_event_invite_token(),
    'accepted',
    v_host_id,
    v_host_id,
    now(),
    now(),
    'Host party membership',
    jsonb_build_object('is_host', true)
  )
  on conflict (event_id, guest_identity_key) do update
  set guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      accepted_by = coalesce(public.event_invites.accepted_by, excluded.accepted_by),
      accepted_at = coalesce(public.event_invites.accepted_at, excluded.accepted_at),
      status = case
        when public.event_invites.status = 'checked_in' then 'checked_in'
        when public.event_invites.status in ('accepted', 'pending') then 'accepted'
        else public.event_invites.status
      end,
      metadata = coalesce(public.event_invites.metadata, '{}'::jsonb)
        || jsonb_build_object('is_host', true),
      updated_at = now()
  returning * into v_invite;

  insert into public.event_guests (
    event_id,
    invite_id,
    member_id,
    guest_name,
    guest_email,
    guest_phone,
    status,
    accepted_at
  ) values (
    p_event_id,
    v_invite.id,
    v_host_id,
    v_name,
    v_email,
    v_phone,
    'accepted',
    now()
  )
  on conflict (event_id, member_id) do update
  set invite_id = excluded.invite_id,
      guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      status = case
        when public.event_guests.status = 'checked_in' then 'checked_in'
        else 'accepted'
      end,
      accepted_at = coalesce(public.event_guests.accepted_at, excluded.accepted_at),
      updated_at = now()
  returning * into v_guest;

  return v_guest;
end;
$$;

-- ---------------------------------------------------------------------------
-- Host: mint a guest invite (unique per guest) after the event exists
-- ---------------------------------------------------------------------------

create or replace function public.create_hosted_event_invite(
  p_event_id uuid,
  p_guest_name text,
  p_guest_email text default null,
  p_guest_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events%rowtype;
  v_name text := trim(coalesce(p_guest_name, ''));
  v_email text := lower(nullif(trim(coalesce(p_guest_email, '')), ''));
  v_phone text := nullif(trim(coalesce(p_guest_phone, '')), '');
  v_invite public.event_invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required.';
  end if;

  if length(v_name) < 2 then
    raise exception 'Guest name is required.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Hosted event not found.';
  end if;

  if v_event.host_id is distinct from auth.uid()
     and v_event.requested_by is distinct from auth.uid()
     and not public.is_admin() then
    raise exception 'Only the host can invite guests.';
  end if;

  if coalesce(v_event.approval_status, 'pending_review') = 'rejected' then
    raise exception 'Cannot invite guests to a rejected event.';
  end if;

  insert into public.event_invites (
    event_id,
    guest_name,
    guest_email,
    guest_phone,
    guest_identity_key,
    invite_code,
    invite_token,
    status,
    created_by,
    last_sent_at
  ) values (
    p_event_id,
    v_name,
    v_email,
    v_phone,
    public.event_guest_identity_key(v_name, v_email, v_phone),
    public.generate_event_invite_code(),
    public.generate_event_invite_token(),
    'pending',
    auth.uid(),
    now()
  )
  on conflict (event_id, guest_identity_key) do update
  set guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      last_sent_at = now(),
      updated_at = now()
  returning * into v_invite;

  -- Mirror into admin guest list when no matching row exists yet.
  if to_regclass('public.guest_list_entries') is not null
     and not exists (
       select 1
       from public.guest_list_entries gle
       where gle.event_id = p_event_id
         and (
           (v_email is not null and lower(trim(coalesce(gle.email, ''))) = v_email)
           or (
             v_email is null
             and lower(trim(gle.name)) = lower(v_name)
             and coalesce(gle.phone, '') = coalesce(v_phone, '')
           )
         )
     ) then
    insert into public.guest_list_entries (
      event_id,
      name,
      email,
      phone,
      status,
      invite_code,
      invited_at,
      added_by,
      member_id
    ) values (
      p_event_id,
      v_name,
      v_email,
      v_phone,
      'invited',
      v_invite.invite_code,
      now(),
      auth.uid(),
      (
        select p.id
        from public.profiles p
        where v_email is not null
          and lower(trim(coalesce(p.email, ''))) = v_email
        limit 1
      )
    );
  end if;

  return jsonb_build_object(
    'invite_id', v_invite.id,
    'event_id', v_event.id,
    'guest_name', v_invite.guest_name,
    'guest_email', v_invite.guest_email,
    'guest_phone', v_invite.guest_phone,
    'invite_code', v_invite.invite_code,
    'invite_token', v_invite.invite_token,
    'status', v_invite.status,
    'title', v_event.title,
    'branch', v_event.branch,
    'starts_at', v_event.starts_at,
    'ends_at', v_event.ends_at,
    'host_name', coalesce(v_event.host_name, 'Host')
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Runtime sync: promote live + apply shared wallet decay
-- ---------------------------------------------------------------------------

create or replace function public.sync_club_event_runtime_statuses()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Past end → completed (scheduled or live; never touch cancelled).
  update public.club_events
  set status = 'completed'
  where coalesce(status, 'scheduled') <> 'cancelled'
    and ends_at is not null
    and now() >= ends_at
    and coalesce(status, 'scheduled') <> 'completed';

  -- Approved + in window → live; seed decay anchor at starts_at.
  update public.club_events
  set status = 'live',
      wallet_last_decayed_at = coalesce(
        wallet_last_decayed_at,
        greatest(starts_at, now())
      )
  where coalesce(approval_status, 'pending_review') = 'approved'
    and coalesce(status, 'scheduled') in ('scheduled', 'live')
    and public.is_event_active(starts_at, ends_at);

  -- Approved but still before start → scheduled (handles edited starts_at).
  update public.club_events
  set status = 'scheduled'
  where coalesce(approval_status, 'pending_review') = 'approved'
    and coalesce(status, 'scheduled') = 'live'
    and starts_at is not null
    and starts_at > now()
    and (ends_at is null or ends_at > now());

  perform public.apply_event_wallet_passive_decay(null);
end;
$$;

-- ---------------------------------------------------------------------------
-- Approval: ensure host membership when approved
-- ---------------------------------------------------------------------------

create or replace function public.admin_review_event_request(
  p_event_id uuid,
  p_decision text,
  p_admin_review_notes text default null
)
returns public.club_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events;
  v_decision text := lower(trim(coalesce(p_decision, '')));
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  if v_decision not in ('approved', 'rejected', 'needs_revision') then
    raise exception 'Invalid review decision.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event request not found.';
  end if;

  update public.club_events
  set approval_status = v_decision,
      admin_review_notes = nullif(trim(coalesce(p_admin_review_notes, '')), ''),
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      approved_at = case when v_decision = 'approved' then now() else approved_at end,
      rejected_at = case when v_decision = 'rejected' then now() else null end
  where id = p_event_id
  returning * into v_event;

  if v_decision = 'approved' then
    perform public.ensure_host_event_membership(p_event_id);
  end if;

  insert into public.member_notifications (
    sender_id,
    recipient_id,
    kind,
    message,
    metadata
  ) values (
    auth.uid(),
    coalesce(v_event.requested_by, v_event.host_id),
    case v_decision
      when 'approved' then 'event_request_approved'
      when 'rejected' then 'event_request_rejected'
      else 'event_request_needs_revision'
    end,
    case v_decision
      when 'approved' then 'Your event request "' || v_event.title || '" was approved.'
      when 'rejected' then 'Your event request "' || v_event.title || '" was rejected.'
      else 'Your event request "' || v_event.title || '" needs revision.'
    end,
    jsonb_build_object(
      'event_id', v_event.id,
      'event_title', v_event.title,
      'approval_status', v_event.approval_status,
      'review_notes', v_event.admin_review_notes
    )
  );

  return v_event;
end;
$$;

-- ---------------------------------------------------------------------------
-- Guest active attendance: decay first, include host membership
-- ---------------------------------------------------------------------------

create or replace function public.get_active_event_for_member(
  p_member_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
  v_session_branch text;
  v_host_event_id uuid;
begin
  perform public.sync_club_event_runtime_statuses();

  v_member_id := coalesce(p_member_id, auth.uid());

  -- Make sure this member is on their own hosted events as a guest.
  for v_host_event_id in
    select ce.id
    from public.club_events ce
    where coalesce(ce.host_id, ce.requested_by) = v_member_id
      and public.is_event_approved_for_ops(ce.approval_status, ce.status)
      and public.is_event_on_for_door_checkin(ce.starts_at, ce.ends_at)
  loop
    perform public.ensure_host_event_membership(v_host_event_id);
  end loop;

  select nullif(trim(cs.branch), '')
    into v_session_branch
  from public.club_sessions cs
  where cs.member_id = v_member_id
    and cs.phase in ('inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry')
  order by
    case cs.phase
      when 'inside_club' then 0
      when 'awaiting_exit_scan' then 1
      else 2
    end,
    cs.entered_at desc nulls last,
    cs.created_at desc
  limit 1;

  return (
    select to_jsonb(row_data)
    from (
      select
        ce.id as event_id,
        ce.title,
        ce.branch,
        ce.starts_at,
        ce.ends_at,
        ce.event_type,
        ce.minimum_pax,
        ce.host_id,
        coalesce(ce.host_name, 'Host') as host_name,
        ce.wallet_seconds,
        ce.wallet_low_threshold_seconds,
        ei.id as invite_id,
        ei.invite_code,
        eg.id as event_guest_id,
        eg.guest_name,
        eg.status,
        eg.checked_in_at,
        coalesce(eg.last_checked_in_at, eg.checked_in_at) as last_checked_in_at,
        eg.accepted_at,
        (coalesce(ce.host_id, ce.requested_by) = v_member_id) as is_host
      from public.event_guests eg
      left join public.event_invites ei on ei.id = eg.invite_id
      join public.club_events ce on ce.id = eg.event_id
      where eg.member_id = v_member_id
        and public.is_event_approved_for_ops(ce.approval_status, ce.status)
        and public.is_event_on_for_door_checkin(ce.starts_at, ce.ends_at)
        and public.event_matches_session_branch(ce.branch, v_session_branch)
        and eg.status in ('accepted', 'checked_in')
      order by
        case when eg.status = 'checked_in' then 0 else 1 end,
        case when coalesce(ce.host_id, ce.requested_by) = v_member_id then 0 else 1 end,
        ce.starts_at desc
      limit 1
    ) as row_data
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Drink charge: hosts + checked-in guests (and accepted hosts) may spend
-- ---------------------------------------------------------------------------

create or replace function public.consume_event_wallet_for_drink(
  p_event_id uuid,
  p_seconds int,
  p_order_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.club_events;
  v_guest public.event_guests;
  v_previous_balance int;
  v_is_host boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  if p_seconds <= 0 then
    raise exception 'Invalid spend amount.';
  end if;

  perform public.sync_club_event_runtime_statuses();

  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event is not active.';
  end if;

  v_is_host := coalesce(v_event.host_id, v_event.requested_by) = auth.uid();

  if v_is_host then
    perform public.ensure_host_event_membership(p_event_id);
  end if;

  select *
    into v_guest
  from public.event_guests
  where event_id = p_event_id
    and member_id = auth.uid()
    and status in ('accepted', 'checked_in')
  for update;

  if not found then
    raise exception 'You are not on this event guest list.';
  end if;

  if coalesce(v_event.approval_status, 'pending_review') <> 'approved'
     or not public.is_event_active(v_event.starts_at, v_event.ends_at) then
    raise exception 'Event is not active.';
  end if;

  -- Re-read after decay applied by sync.
  select *
    into v_event
  from public.club_events
  where id = p_event_id
  for update;

  if v_event.wallet_seconds < p_seconds then
    raise exception 'Event wallet needs more time.';
  end if;

  v_previous_balance := v_event.wallet_seconds;

  update public.club_events
  set wallet_seconds = wallet_seconds - p_seconds,
      wallet_consumed_seconds = wallet_consumed_seconds + p_seconds
  where id = p_event_id
  returning * into v_event;

  insert into public.event_wallet_transactions (
    event_id,
    actor_id,
    event_guest_id,
    order_id,
    kind,
    seconds_delta,
    balance_after_seconds,
    note,
    metadata
  ) values (
    p_event_id,
    auth.uid(),
    v_guest.id,
    p_order_id,
    'drink_charge',
    -p_seconds,
    v_event.wallet_seconds,
    'Drink charged against event wallet.',
    jsonb_build_object(
      'member_id', auth.uid(),
      'club_session_id', v_guest.club_session_id,
      'is_host', v_is_host
    )
  );

  if v_event.host_id is not null
     and v_event.wallet_seconds <= v_event.wallet_low_threshold_seconds
     and (
       v_previous_balance > v_event.wallet_low_threshold_seconds
       or v_event.wallet_low_notified_at is null
     ) then
    insert into public.member_notifications (
      sender_id,
      recipient_id,
      kind,
      message,
      metadata
    ) values (
      auth.uid(),
      v_event.host_id,
      'event_wallet_low',
      coalesce(v_guest.guest_name, 'A guest') || ' used event time for a drink. Event wallet is running low.',
      jsonb_build_object(
        'event_id', v_event.id,
        'event_title', v_event.title,
        'remaining_seconds', v_event.wallet_seconds,
        'order_id', p_order_id
      )
    );

    update public.club_events
    set wallet_low_notified_at = now()
    where id = p_event_id
    returning * into v_event;
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'wallet_seconds', v_event.wallet_seconds,
    'wallet_low_threshold_seconds', v_event.wallet_low_threshold_seconds,
    'order_id', p_order_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Hosted list applies decay so the host UI ticks with the shared wallet
-- ---------------------------------------------------------------------------

create or replace function public.list_my_hosted_events()
returns setof public.club_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
begin
  perform public.sync_club_event_runtime_statuses();

  for v_event_id in
    select ce.id
    from public.club_events ce
    where (ce.host_id = auth.uid() or ce.requested_by = auth.uid())
      and public.is_event_approved_for_ops(ce.approval_status, ce.status)
  loop
    perform public.ensure_host_event_membership(v_event_id);
  end loop;

  return query
  select ce.*
  from public.club_events ce
  where ce.host_id = auth.uid() or ce.requested_by = auth.uid()
  order by ce.starts_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Backfill host membership for existing approved / live events
-- ---------------------------------------------------------------------------

do $$
declare
  v_event record;
begin
  for v_event in
    select id
    from public.club_events
    where coalesce(host_id, requested_by) is not null
      and coalesce(approval_status, 'pending_review') in ('approved', 'pending_review', 'needs_revision')
      and coalesce(status, 'scheduled') <> 'cancelled'
  loop
    begin
      perform public.ensure_host_event_membership(v_event.id);
    exception when others then
      -- Skip broken legacy rows; do not fail the migration.
      raise notice 'ensure_host_event_membership skipped for %: %', v_event.id, sqlerrm;
    end;
  end loop;
end;
$$;

-- Seed decay anchors for currently live events.
update public.club_events
set wallet_last_decayed_at = coalesce(wallet_last_decayed_at, greatest(starts_at, now()))
where coalesce(approval_status, 'pending_review') = 'approved'
  and public.is_event_active(starts_at, ends_at);

select public.sync_club_event_runtime_statuses();

grant execute on function public.apply_event_wallet_passive_decay(uuid) to authenticated;
grant execute on function public.ensure_host_event_membership(uuid) to authenticated;
grant execute on function public.create_hosted_event_invite(uuid, text, text, text) to authenticated;
grant execute on function public.get_active_event_for_member(uuid) to authenticated;
grant execute on function public.consume_event_wallet_for_drink(uuid, int, uuid) to authenticated;
grant execute on function public.list_my_hosted_events() to authenticated;
grant execute on function public.admin_review_event_request(uuid, text, text) to authenticated;
