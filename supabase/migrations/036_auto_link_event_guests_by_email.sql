-- Auto-link admin guest list / invite rows to app accounts by email.
--
-- Gaps this closes
-- ----------------
-- 1) Admin add-time already resolves member_id in admin-web when a profile
--    exists, but rows added before signup stay unlinked forever.
-- 2) Mobile reads only event_guests.member_id = auth.uid(). Unlinked
--    guest_list_entries never become event_guests (028 sync returns early).
-- 3) accept_event_invite created event_guests but did not backfill
--    guest_list_entries.member_id.
-- 4) handle_new_user / profile insert never peered pending guest emails.
--
-- After this migration: profile create/email update, and invite accept, both
-- call link_event_guest_rows_for_member so FIESTA-style admin guests attach
-- the moment the matching account exists.

-- ---------------------------------------------------------------------------
-- 1. Improve admin guest → invite/guest mirror: linked members count as accepted
-- ---------------------------------------------------------------------------

create or replace function public.sync_guest_list_entry_to_event_contract(p_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  gle public.guest_list_entries%rowtype;
  v_invite_id uuid;
  v_guest_status text;
  v_invite_status text;
begin
  select *
    into gle
  from public.guest_list_entries
  where id = p_entry_id;

  if not found then
    return;
  end if;

  v_guest_status := case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('revoked', 'denied') then 'revoked'
    else 'accepted'
  end;

  -- Admin-linked members are already on the door list — treat as accepted so
  -- the hub shows a confirmed card instead of an unanswered invite.
  v_invite_status := case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('registered', 'confirmed') then 'accepted'
    when gle.status in ('denied', 'revoked') then 'revoked'
    when gle.status = 'no_show' then 'expired'
    when gle.member_id is not null then 'accepted'
    else 'pending'
  end;

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
    created_at,
    updated_at
  ) values (
    gle.event_id,
    gle.name,
    gle.email,
    gle.phone,
    public.event_guest_identity_key(gle.name, gle.email, gle.phone),
    upper(coalesce(nullif(trim(gle.invite_code), ''), public.generate_event_invite_code())),
    public.generate_event_invite_token(),
    v_invite_status,
    gle.added_by,
    coalesce(gle.invite_claimed_by, gle.member_id),
    coalesce(gle.accepted_at, gle.invite_claimed_at, case when gle.member_id is not null then gle.created_at end),
    coalesce(gle.invited_at, gle.created_at),
    gle.notes,
    gle.created_at,
    greatest(
      gle.created_at,
      coalesce(gle.accepted_at, gle.invite_claimed_at, gle.checked_in_at, gle.created_at)
    )
  )
  on conflict (event_id, guest_identity_key) do update
  set guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      status = excluded.status,
      accepted_by = coalesce(public.event_invites.accepted_by, excluded.accepted_by),
      accepted_at = coalesce(public.event_invites.accepted_at, excluded.accepted_at),
      notes = excluded.notes,
      updated_at = excluded.updated_at
  returning id into v_invite_id;

  if gle.member_id is null then
    return;
  end if;

  insert into public.event_guests (
    event_id,
    invite_id,
    member_id,
    guest_name,
    guest_email,
    guest_phone,
    status,
    accepted_at,
    checked_in_at,
    checked_in_by,
    club_session_id,
    created_at,
    updated_at
  ) values (
    gle.event_id,
    v_invite_id,
    gle.member_id,
    gle.name,
    gle.email,
    gle.phone,
    v_guest_status,
    coalesce(gle.accepted_at, gle.invite_claimed_at, gle.created_at),
    gle.checked_in_at,
    gle.checked_in_by,
    gle.check_in_session_id,
    gle.created_at,
    greatest(
      gle.created_at,
      coalesce(gle.checked_in_at, gle.accepted_at, gle.invite_claimed_at, gle.created_at)
    )
  )
  on conflict (event_id, member_id) do update
  set invite_id = excluded.invite_id,
      guest_name = excluded.guest_name,
      guest_email = excluded.guest_email,
      guest_phone = excluded.guest_phone,
      status = case
        when public.event_guests.status = 'checked_in' then 'checked_in'
        else excluded.status
      end,
      accepted_at = coalesce(public.event_guests.accepted_at, excluded.accepted_at),
      checked_in_at = coalesce(public.event_guests.checked_in_at, excluded.checked_in_at),
      checked_in_by = coalesce(public.event_guests.checked_in_by, excluded.checked_in_by),
      club_session_id = coalesce(public.event_guests.club_session_id, excluded.club_session_id),
      updated_at = excluded.updated_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Core linker: peer guest_list_entries + pending invites to a profile email
-- ---------------------------------------------------------------------------

create or replace function public.link_event_guest_rows_for_member(p_member_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_linked integer := 0;
  v_entry_id uuid;
begin
  if p_member_id is null then
    return 0;
  end if;

  select nullif(lower(trim(coalesce(email, ''))), '')
    into v_email
  from public.profiles
  where id = p_member_id;

  if v_email is null then
    return 0;
  end if;

  -- Attach every unlinked admin guest row whose email matches this account.
  for v_entry_id in
    select gle.id
    from public.guest_list_entries gle
    where gle.member_id is null
      and nullif(lower(trim(coalesce(gle.email, ''))), '') = v_email
      and not exists (
        select 1
        from public.guest_list_entries other
        where other.event_id = gle.event_id
          and other.member_id = p_member_id
      )
  loop
    update public.guest_list_entries
    set member_id = p_member_id,
        invite_claimed_by = coalesce(invite_claimed_by, p_member_id),
        invite_claimed_at = coalesce(invite_claimed_at, now()),
        accepted_at = coalesce(accepted_at, now())
    where id = v_entry_id;
    -- AFTER UPDATE trigger mirrors into event_invites / event_guests.
    v_linked := v_linked + 1;
  end loop;

  -- Pending invites by email that never had a guest_list_entries member_id
  -- (or were created outside the admin guest list) still need event_guests.
  insert into public.event_guests (
    event_id,
    invite_id,
    member_id,
    guest_name,
    guest_email,
    guest_phone,
    status,
    accepted_at
  )
  select
    ei.event_id,
    ei.id,
    p_member_id,
    ei.guest_name,
    ei.guest_email,
    ei.guest_phone,
    case
      when ei.status = 'checked_in' then 'checked_in'
      else 'accepted'
    end,
    coalesce(ei.accepted_at, now())
  from public.event_invites ei
  where nullif(lower(trim(coalesce(ei.guest_email, ''))), '') = v_email
    and ei.status not in ('revoked', 'expired')
    and not exists (
      select 1
      from public.event_guests eg
      where eg.event_id = ei.event_id
        and eg.member_id = p_member_id
    )
    and (
      ei.accepted_by is null
      or ei.accepted_by = p_member_id
    )
  on conflict (event_id, member_id) do nothing;

  update public.event_invites ei
  set accepted_by = coalesce(ei.accepted_by, p_member_id),
      accepted_at = coalesce(ei.accepted_at, now()),
      status = case
        when ei.status in ('checked_in', 'revoked', 'expired') then ei.status
        else 'accepted'
      end,
      updated_at = now()
  where nullif(lower(trim(coalesce(ei.guest_email, ''))), '') = v_email
    and ei.status not in ('revoked', 'expired')
    and (ei.accepted_by is null or ei.accepted_by = p_member_id);

  return v_linked;
end;
$$;

grant execute on function public.link_event_guest_rows_for_member(uuid) to authenticated;
grant execute on function public.link_event_guest_rows_for_member(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Fire linker whenever a profile is created or its email is set/changed
-- ---------------------------------------------------------------------------

create or replace function public.trg_profiles_link_event_guests()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.link_event_guest_rows_for_member(new.id);
  return new;
end;
$$;

drop trigger if exists trg_profiles_link_event_guests on public.profiles;
create trigger trg_profiles_link_event_guests
  after insert or update of email on public.profiles
  for each row
  execute function public.trg_profiles_link_event_guests();

-- Keep handle_new_user in sync: profile insert already triggers the linker,
-- but call it explicitly after insert so older trigger stacks still link.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, birthdate, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.email, ''),
    nullif(new.raw_user_meta_data->>'birthdate', '')::date,
    coalesce(new.raw_user_meta_data->>'role', 'member')
  )
  on conflict (id) do update
  set email = coalesce(nullif(trim(excluded.email), ''), public.profiles.email),
      name = case
        when nullif(trim(excluded.name), '') is null then public.profiles.name
        else excluded.name
      end;

  perform public.link_event_guest_rows_for_member(new.id);
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Invite accept also peers the matching guest_list_entries row
-- ---------------------------------------------------------------------------

create or replace function public.accept_event_invite(
  p_code text,
  p_accept_via text default 'code'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_invite public.event_invites%rowtype;
  v_event public.club_events%rowtype;
  v_guest public.event_guests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in required.';
  end if;

  perform public.sync_club_event_runtime_statuses();

  select *
    into v_profile
  from public.profiles
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found.';
  end if;

  select *
    into v_invite
  from public.event_invites
  where invite_code = upper(trim(coalesce(p_code, '')))
  for update;

  if not found then
    raise exception 'Invite code not found.';
  end if;

  select *
    into v_event
  from public.club_events
  where id = v_invite.event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if coalesce(v_event.status, 'scheduled') = 'cancelled' then
    raise exception 'This event was cancelled.';
  end if;

  if v_event.approval_status <> 'approved' then
    raise exception 'Event is not approved yet.';
  end if;

  if v_event.ends_at is null
     or now() >= v_event.ends_at
     or coalesce(v_event.status, 'scheduled') = 'completed' then
    raise exception 'This invite has expired.';
  end if;

  if v_invite.status in ('revoked', 'expired') then
    raise exception 'This invite is no longer valid.';
  end if;

  if nullif(lower(trim(coalesce(v_invite.guest_email, ''))), '') is not null
     and lower(trim(coalesce(v_profile.email, ''))) <> lower(trim(coalesce(v_invite.guest_email, ''))) then
    raise exception 'Invite email does not match this account.';
  end if;

  if v_invite.accepted_by is not null and v_invite.accepted_by <> auth.uid() then
    raise exception 'Invite already claimed.';
  end if;

  if exists (
    select 1
    from public.event_guests eg
    where eg.event_id = v_invite.event_id
      and eg.member_id = auth.uid()
      and eg.invite_id is distinct from v_invite.id
  ) then
    raise exception 'You already have an invite for this event.';
  end if;

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
    v_invite.event_id,
    v_invite.id,
    auth.uid(),
    v_invite.guest_name,
    v_invite.guest_email,
    v_invite.guest_phone,
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
        accepted_at = coalesce(public.event_guests.accepted_at, excluded.accepted_at)
  returning * into v_guest;

  update public.event_invites
  set accepted_by = auth.uid(),
      accepted_at = now(),
      status = case
        when status = 'checked_in' then status
        else 'accepted'
      end
  where id = v_invite.id
  returning * into v_invite;

  -- Peer the admin guest-list row for this event/email so door + admin stay aligned.
  update public.guest_list_entries gle
  set member_id = auth.uid(),
      invite_claimed_by = coalesce(gle.invite_claimed_by, auth.uid()),
      invite_claimed_at = coalesce(gle.invite_claimed_at, now()),
      accepted_at = coalesce(gle.accepted_at, now())
  where gle.event_id = v_invite.event_id
    and gle.member_id is null
    and (
      nullif(lower(trim(coalesce(gle.email, ''))), '')
        = nullif(lower(trim(coalesce(v_profile.email, ''))), '')
      or public.event_guest_identity_key(gle.name, gle.email, gle.phone)
        = v_invite.guest_identity_key
    )
    and not exists (
      select 1
      from public.guest_list_entries other
      where other.event_id = gle.event_id
        and other.member_id = auth.uid()
        and other.id <> gle.id
    );

  perform public.link_event_guest_rows_for_member(auth.uid());

  return jsonb_build_object(
    'invite_id', v_invite.id,
    'event_guest_id', v_guest.id,
    'event_id', v_event.id,
    'title', v_event.title,
    'branch', v_event.branch,
    'starts_at', v_event.starts_at,
    'ends_at', v_event.ends_at,
    'event_type', v_event.event_type,
    'minimum_pax', v_event.minimum_pax,
    'host_id', v_event.host_id,
    'host_name', coalesce(v_event.host_name, 'Host'),
    'guest_name', v_guest.guest_name,
    'status', v_guest.status,
    'accepted_at', v_guest.accepted_at,
    'accepted_via', case
      when lower(trim(coalesce(p_accept_via, 'code'))) = 'token' then 'token'
      else 'code'
    end
  );
end;
$$;

grant execute on function public.accept_event_invite(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. One-shot backfill for existing profiles ↔ unlinked guest emails
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select id from public.profiles
    where nullif(lower(trim(coalesce(email, ''))), '') is not null
  loop
    perform public.link_event_guest_rows_for_member(r.id);
  end loop;
end;
$$;
