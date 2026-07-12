-- Realtime currency: wallet balance + time transfers sync live to all devices.

alter table public.profiles replica identity full;
alter table public.club_sessions replica identity full;

-- Wallet balance updates (tips received, visit banked, purchases to wallet)
alter publication supabase_realtime add table public.profiles;

-- Tip / toast events (bartender pad, pass the glass)
alter publication supabase_realtime add table public.time_transfers;
