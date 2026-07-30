-- Soft-launch / QA one-shot: reset every member's personal time wallet.
--
-- Value: 3 hours = 10800 seconds (matches a Standard Night-style test load).
-- Source of truth: profiles.time_balance_seconds (unified wallet — see 009).
-- Active club_sessions.remaining_seconds stay at 0; VIP room tabs are left alone.
--
-- Idempotent outcome: re-running sets the same balance again.
-- Marked in public._ops_one_shots so ops can see it was applied once for audit.
--
-- Run via: Supabase SQL editor (paste this file) OR `supabase db push` when linked.
-- Do NOT invent credentials; this migration is safe to apply manually.

create table if not exists public._ops_one_shots (
  key text primary key,
  applied_at timestamptz not null default now(),
  notes text
);

do $$
declare
  v_reset_seconds int := 10800; -- 3 hours
  v_updated int;
begin
  update public.profiles
  set time_balance_seconds = v_reset_seconds
  where coalesce(role, 'member') = 'member';

  get diagnostics v_updated = row_count;

  insert into public._ops_one_shots (key, notes)
  values (
    '032_reset_all_member_time_balances',
    format(
      'Set member profiles.time_balance_seconds = %s (%s rows). Soft-launch QA reset.',
      v_reset_seconds,
      v_updated
    )
  )
  on conflict (key) do update
    set applied_at = now(),
        notes = excluded.notes;

  raise notice
    '032_reset_all_member_time_balances: set % member wallets to % seconds',
    v_updated,
    v_reset_seconds;
end;
$$;
