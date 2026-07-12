-- Time as currency: one balance on profiles.time_balance_seconds.
-- Active visits no longer hold a separate time pool.

-- Move any time still sitting in open sessions into the wallet.
update public.profiles p
set time_balance_seconds = p.time_balance_seconds + coalesce(s.active_seconds, 0)
from (
  select member_id, sum(remaining_seconds) as active_seconds
  from public.club_sessions
  where phase in ('inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry')
  group by member_id
) s
where p.id = s.member_id;

update public.club_sessions
set remaining_seconds = 0
where phase in ('inside_club', 'awaiting_exit_scan', 'paid_awaiting_entry');

-- Session completion no longer banks time — wallet is already the source of truth.
drop trigger if exists club_sessions_bank_time_on_complete on public.club_sessions;
drop function if exists public.bank_time_on_session_complete();
