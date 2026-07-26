-- Auto badge-out: any in-club visit left open for 48 hours is completed.

create or replace function public.complete_stale_club_sessions(
  p_member_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  v_is_staff boolean := false;
begin
  if auth.uid() is null then
    return 0;
  end if;

  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('staff', 'admin', 'hr')
  )
    into v_is_staff;

  update public.club_sessions
  set phase = 'completed',
      exited_at = entered_at + interval '48 hours'
  where phase in ('inside_club', 'awaiting_exit_scan')
    and entered_at is not null
    and entered_at <= now() - interval '48 hours'
    and (
      member_id = auth.uid()
      or (v_is_staff and (p_member_id is null or member_id = p_member_id))
    );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.complete_stale_club_sessions(uuid) to authenticated;
