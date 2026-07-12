-- Bank unused club time on profiles so guests keep their balance across visits.

alter table public.profiles
  add column if not exists time_balance_seconds int not null default 0;

create or replace function public.bank_time_on_session_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.phase = 'completed'
     and old.phase = 'awaiting_exit_scan'
     and new.remaining_seconds > 0 then
    update public.profiles
    set time_balance_seconds = time_balance_seconds + new.remaining_seconds
    where id = new.member_id;
  end if;
  return new;
end;
$$;

drop trigger if exists club_sessions_bank_time_on_complete on public.club_sessions;
create trigger club_sessions_bank_time_on_complete
  after update on public.club_sessions
  for each row
  execute function public.bank_time_on_session_complete();
