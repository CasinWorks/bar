-- Repair script: make admin-added guest list rows visible to the mobile app.
--
-- Why this is needed
-- ------------------
-- admin-web writes guests to public.guest_list_entries only, and leaves
-- member_id null when the admin types a name/email instead of picking a member.
-- The mobile app never reads guest_list_entries: list_my_event_invites and
-- get_active_event_for_member both start from public.event_guests and require
-- event_guests.member_id = auth.uid(). A guest_list_entries row with a null
-- member_id therefore produces:
--   * no card in Events & Calendar (nothing in event_guests for that member)
--   * no door welcome overlay (staff_check_in_event_guest finds no guest row)
--
-- Migration 028 added a trigger that mirrors guest_list_entries into
-- event_invites / event_guests, but 028 is NOT applied on this database yet
-- (public.sync_club_event_runtime_statuses and public.is_event_approved_for_ops
-- do not exist). This script does the same repair using only functions that
-- exist at migration 027, so it is safe to run now, and it is idempotent.
--
-- Run this in the Supabase SQL editor. Safe to re-run.
-- Apply migrations 028+ afterwards so new admin guests sync automatically.

begin;

-- ---------------------------------------------------------------------------
-- 1. Resolve member_id from the guest email so the mobile app can match rows.
--    Skipped when another entry on the same event already claims that member
--    (guest_list_entries has a unique index on (event_id, member_id)).
-- ---------------------------------------------------------------------------

update public.guest_list_entries gle
set member_id = p.id
from public.profiles p
where gle.member_id is null
  and nullif(lower(trim(coalesce(gle.email, ''))), '') is not null
  and lower(trim(p.email)) = lower(trim(gle.email))
  and not exists (
    select 1
    from public.guest_list_entries other
    where other.event_id = gle.event_id
      and other.member_id = p.id
  );

-- ---------------------------------------------------------------------------
-- 2. Event contract sanity: host_id and a real end time.
--    Scoped to approved events so validate_club_event_request() cannot trip
--    its 7-day lead time rule on pending requests.
-- ---------------------------------------------------------------------------

update public.club_events
set host_id = created_by
where host_id is null
  and created_by is not null;

update public.club_events
set ends_at = starts_at + interval '8 hours'
where ends_at is null
  and starts_at is not null
  and coalesce(approval_status, 'pending_review') = 'approved';

-- ---------------------------------------------------------------------------
-- 3. Mirror every guest list row into event_invites (the app's invite table).
--    Existing invite codes/tokens are preserved on conflict. One invite per
--    (event, guest identity) — newest guest list row wins.
-- ---------------------------------------------------------------------------

with deduped as (
  select distinct on (gle.event_id, public.event_guest_identity_key(gle.name, gle.email, gle.phone))
    gle.*,
    public.event_guest_identity_key(gle.name, gle.email, gle.phone) as identity_key
  from public.guest_list_entries gle
  join public.club_events ce on ce.id = gle.event_id
  order by
    gle.event_id,
    public.event_guest_identity_key(gle.name, gle.email, gle.phone),
    gle.member_id nulls last,
    gle.created_at desc
)
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
)
select
  gle.event_id,
  gle.name,
  gle.email,
  gle.phone,
  gle.identity_key,
  upper(coalesce(nullif(trim(gle.invite_code), ''), public.generate_event_invite_code())),
  public.generate_event_invite_token(),
  case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('denied', 'revoked') then 'revoked'
    when gle.status = 'no_show' then 'expired'
    -- A member-linked admin guest is already on the list; treat as accepted so
    -- the hub shows a confirmed card instead of an unanswered invite.
    when gle.member_id is not null then 'accepted'
    else 'pending'
  end,
  gle.added_by,
  coalesce(gle.invite_claimed_by, gle.member_id),
  coalesce(gle.accepted_at, gle.invite_claimed_at, gle.created_at),
  coalesce(gle.invited_at, gle.created_at),
  gle.notes,
  gle.created_at,
  now()
from deduped gle
on conflict (event_id, guest_identity_key) do update
set guest_name = excluded.guest_name,
    guest_email = excluded.guest_email,
    guest_phone = excluded.guest_phone,
    status = excluded.status,
    accepted_by = coalesce(public.event_invites.accepted_by, excluded.accepted_by),
    accepted_at = coalesce(public.event_invites.accepted_at, excluded.accepted_at),
    notes = excluded.notes,
    updated_at = now();

-- ---------------------------------------------------------------------------
-- 4. Create the event_guests row the app actually reads.
--    status 'accepted' is what list_my_event_invites and
--    get_active_event_for_member require (they accept 'accepted' or
--    'checked_in'); the door scan flips it to 'checked_in'.
-- ---------------------------------------------------------------------------

with linkable as (
  -- event_guests.invite_id is unique, so only one member may claim an invite.
  select distinct on (ei.id)
    gle.*,
    ei.id as invite_id
  from public.guest_list_entries gle
  join public.event_invites ei
    on ei.event_id = gle.event_id
   and ei.guest_identity_key = public.event_guest_identity_key(gle.name, gle.email, gle.phone)
  where gle.member_id is not null
  order by ei.id, gle.created_at desc
)
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
)
select
  gle.event_id,
  gle.invite_id,
  gle.member_id,
  gle.name,
  gle.email,
  gle.phone,
  case
    when gle.status = 'checked_in' then 'checked_in'
    when gle.status in ('denied', 'revoked') then 'revoked'
    else 'accepted'
  end,
  coalesce(gle.accepted_at, gle.invite_claimed_at, gle.created_at),
  gle.checked_in_at,
  gle.checked_in_by,
  gle.check_in_session_id,
  gle.created_at,
  now()
from linkable gle
on conflict (event_id, member_id) do update
set invite_id = excluded.invite_id,
    guest_name = excluded.guest_name,
    guest_email = excluded.guest_email,
    guest_phone = excluded.guest_phone,
    status = case
      when public.event_guests.status = 'checked_in' then 'checked_in'
      else excluded.status
    end,
    accepted_at = excluded.accepted_at,
    checked_in_at = coalesce(public.event_guests.checked_in_at, excluded.checked_in_at),
    checked_in_by = coalesce(public.event_guests.checked_in_by, excluded.checked_in_by),
    club_session_id = coalesce(public.event_guests.club_session_id, excluded.club_session_id),
    updated_at = now();

commit;

-- ---------------------------------------------------------------------------
-- OPTIONAL: force the door check-in for a guest who is already inside.
--
-- Step 4 leaves the guest as 'accepted', which is what the hub needs. The
-- welcome overlay additionally needs status = 'checked_in', which normally
-- happens when door staff scan the guest QR (staff_check_in_event_guest).
-- Uncomment this to simulate that scan against the guest's live club session,
-- e.g. to test the overlay without walking back to the door.
-- ---------------------------------------------------------------------------

-- update public.event_guests eg
-- set status = 'checked_in',
--     checked_in_at = coalesce(eg.checked_in_at, now()),
--     club_session_id = cs.id,
--     updated_at = now()
-- from public.profiles p
-- join public.club_sessions cs
--   on cs.member_id = p.id
--  and cs.exited_at is null
--  and cs.entered_at is not null
-- where eg.member_id = p.id
--   and eg.status = 'accepted'
--   and p.email = 'christianjoshuacasin@gmail.com';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------

-- Any guest list row the app still cannot see (no member match by email):
select
  gle.id,
  gle.event_id,
  gle.name,
  gle.email,
  gle.phone,
  gle.status
from public.guest_list_entries gle
where gle.member_id is null
order by gle.created_at desc;

-- What the mobile hub will return per member (mirrors list_my_event_invites):
select
  p.email                as member_email,
  eg.member_id,
  ce.title,
  ce.approval_status,
  ce.status              as event_status,
  ce.starts_at,
  ce.ends_at,
  ei.invite_code,
  eg.status              as guest_status,
  eg.checked_in_at,
  public.is_event_active(ce.starts_at, ce.ends_at) as in_window
from public.event_guests eg
join public.event_invites ei on ei.id = eg.invite_id
join public.club_events ce on ce.id = eg.event_id
join public.profiles p on p.id = eg.member_id
order by ce.starts_at desc;
