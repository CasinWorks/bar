-- VIP room / couch tab fields on club sessions.
-- Required by ClubSessionRecord.toSupabaseRow(); without these columns,
-- member visit creation (upsert) fails and guests cannot enter the club.

alter table public.club_sessions
  add column if not exists active_vip_room_slug text,
  add column if not exists vip_room_time_seconds int not null default 0,
  add column if not exists vip_room_drink_minutes_spent int not null default 0;
