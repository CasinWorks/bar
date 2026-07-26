-- Accurate Who's Inside: active session + same branch + fresh heartbeat only.

create or replace function public.set_open_to_meet(
  p_open boolean,
  p_branch text,
  p_session_id uuid default null,
  p_vibe_tag text default 'Looking for a toast'
)
returns public.social_presence
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_row public.social_presence;
  v_branch text := coalesce(nullif(trim(p_branch), ''), 'Unknown');
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select name into v_name from public.profiles where id = auth.uid();

  if p_open then
    if p_session_id is null or not exists (
      select 1
      from public.club_sessions cs
      where cs.id = p_session_id
        and cs.member_id = auth.uid()
        and cs.branch = v_branch
        and cs.phase = 'inside_club'
        and cs.entered_at is not null
        and cs.entered_at > now() - interval '48 hours'
    ) then
      raise exception 'Active inside session required.';
    end if;
  end if;

  insert into public.social_presence as sp (
    member_id, session_id, branch, display_name, vibe_tag, open_to_meet, updated_at
  ) values (
    auth.uid(),
    p_session_id,
    v_branch,
    coalesce(v_name, 'Guest'),
    coalesce(nullif(trim(p_vibe_tag), ''), 'Looking for a toast'),
    p_open,
    now()
  )
  on conflict (member_id) do update set
    session_id = excluded.session_id,
    branch = excluded.branch,
    display_name = excluded.display_name,
    vibe_tag = excluded.vibe_tag,
    open_to_meet = excluded.open_to_meet,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.list_whos_inside(p_branch text)
returns setof public.social_presence
language sql
security definer
set search_path = public
stable
as $$
  select sp.*
  from public.social_presence sp
  join public.club_sessions cs
    on cs.id = sp.session_id
   and cs.member_id = sp.member_id
   and cs.branch = sp.branch
  where sp.open_to_meet = true
    and sp.branch = p_branch
    and sp.updated_at > now() - interval '90 seconds'
    and cs.phase = 'inside_club'
    and cs.entered_at is not null
    and cs.entered_at > now() - interval '48 hours'
    and not public.has_member_block(auth.uid(), sp.member_id)
  order by sp.updated_at desc;
$$;
