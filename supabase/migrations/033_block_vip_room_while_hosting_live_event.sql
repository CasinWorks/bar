-- Guard: hosts of a live approved event cannot keep / book a VIP room tab.
-- Mirrors client rule in VipHostedEventConflict / AppState._bookVipRoom.
-- Client still enforces UX; this keeps session upserts honest.

create or replace function public.member_hosts_live_event(p_member_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.club_events ce
    where ce.host_id = p_member_id
      and coalesce(ce.approval_status, 'pending_review') = 'approved'
      and coalesce(ce.status, 'scheduled') <> 'cancelled'
      and public.is_event_active(ce.starts_at, ce.ends_at)
  );
$$;

revoke all on function public.member_hosts_live_event(uuid) from public;
grant execute on function public.member_hosts_live_event(uuid) to authenticated;
grant execute on function public.member_hosts_live_event(uuid) to service_role;

create or replace function public.guard_vip_room_vs_hosted_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.member_id is null then
    return new;
  end if;

  if public.member_hosts_live_event(new.member_id)
     and (
       (new.active_vip_room_slug is not null and new.active_vip_room_slug <> '')
       or coalesce(new.vip_room_time_seconds, 0) > 0
     ) then
    new.active_vip_room_slug := null;
    new.vip_room_time_seconds := 0;
    new.vip_room_drink_minutes_spent := 0;
  end if;

  return new;
end;
$$;

drop trigger if exists club_sessions_guard_vip_vs_hosted_event on public.club_sessions;
create trigger club_sessions_guard_vip_vs_hosted_event
  before insert or update of active_vip_room_slug, vip_room_time_seconds, vip_room_drink_minutes_spent
  on public.club_sessions
  for each row
  execute function public.guard_vip_room_vs_hosted_event();

-- Clear any VIP occupancy already held by hosts of currently live events.
update public.club_sessions s
set
  active_vip_room_slug = null,
  vip_room_time_seconds = 0,
  vip_room_drink_minutes_spent = 0
where (
  (s.active_vip_room_slug is not null and s.active_vip_room_slug <> '')
  or coalesce(s.vip_room_time_seconds, 0) > 0
)
and public.member_hosts_live_event(s.member_id)
and s.phase in ('paid_awaiting_entry', 'inside_club', 'awaiting_exit_scan');
