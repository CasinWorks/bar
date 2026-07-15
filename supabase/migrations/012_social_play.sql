-- Social PLAY: opt-in presence, meet toasts, duo Beat Synchronizer lobbies

create table if not exists public.social_presence (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  session_id uuid,
  branch text not null,
  display_name text not null default '',
  vibe_tag text not null default 'Looking for a toast',
  open_to_meet boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists social_presence_branch_open_idx
  on public.social_presence (branch)
  where open_to_meet = true;

alter table public.social_presence enable row level security;

create policy "presence_select_open_or_self"
  on public.social_presence for select
  using (open_to_meet = true or member_id = auth.uid());

create policy "presence_upsert_self"
  on public.social_presence for insert
  with check (member_id = auth.uid());

create policy "presence_update_self"
  on public.social_presence for update
  using (member_id = auth.uid());

create policy "presence_delete_self"
  on public.social_presence for delete
  using (member_id = auth.uid());

create table if not exists public.social_meets (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  host_name text not null default '',
  guest_id uuid references public.profiles(id) on delete set null,
  guest_name text,
  seconds int not null check (seconds > 0),
  kind text not null check (kind in ('meet_toast', 'duo_beat')),
  code text unique,
  icebreaker text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'matched', 'completed')),
  host_score int,
  guest_score int,
  winner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  matched_at timestamptz,
  completed_at timestamptz
);

create index if not exists social_meets_code_idx on public.social_meets (code)
  where code is not null;
create index if not exists social_meets_host_idx on public.social_meets (host_id);
create index if not exists social_meets_guest_idx on public.social_meets (guest_id);

alter table public.social_meets enable row level security;

create policy "meets_select_participants"
  on public.social_meets for select
  using (host_id = auth.uid() or guest_id = auth.uid() or status = 'pending');

-- RPCs are security definer; lock down direct writes
create policy "meets_no_direct_insert"
  on public.social_meets for insert
  with check (false);

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
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  select name into v_name from public.profiles where id = auth.uid();

  insert into public.social_presence as sp (
    member_id, session_id, branch, display_name, vibe_tag, open_to_meet, updated_at
  ) values (
    auth.uid(),
    p_session_id,
    coalesce(nullif(trim(p_branch), ''), 'Unknown'),
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
  select *
  from public.social_presence
  where open_to_meet = true
    and branch = p_branch
    and updated_at > now() - interval '6 hours'
  order by updated_at desc;
$$;

create or replace function public.raise_meet(
  p_seconds int,
  p_kind text default 'meet_toast'
)
returns public.social_meets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
  v_name text;
  v_code text;
  v_prompt text;
  v_row public.social_meets;
  v_prompts text[] := array[
    'Ask them what song they’d freeze time for.',
    'What would you buy with one extra hour tonight?',
    'If this club had a secret password tonight, what should it be?',
    'Who in the room looks like they have the most minutes left?',
    'What’s the last thing you’d spend your final minute on?',
    'Name a cocktail after something you regret — and why.',
    'Would you trade 30 minutes for a stranger’s best story?',
    'What’s your “In Time” villain origin story?'
  ];
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if p_seconds < 60 then
    raise exception 'Minimum pour is 1 minute.';
  end if;
  if p_seconds > 600 then
    raise exception 'Maximum meet pour is 10 minutes.';
  end if;
  if p_kind not in ('meet_toast', 'duo_beat') then
    raise exception 'Invalid meet kind.';
  end if;

  select time_balance_seconds, name
    into v_balance, v_name
  from public.profiles
  where id = auth.uid()
  for update;

  if not found then
    raise exception 'Profile not found.';
  end if;
  if coalesce(v_balance, 0) < p_seconds then
    raise exception 'Not enough time balance.';
  end if;

  update public.profiles
  set time_balance_seconds = time_balance_seconds - p_seconds
  where id = auth.uid();

  v_code := 'MEET-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
  v_prompt := v_prompts[1 + floor(random() * array_length(v_prompts, 1))::int];

  insert into public.social_meets (
    host_id, host_name, seconds, kind, code, icebreaker, status
  ) values (
    auth.uid(), coalesce(v_name, ''), p_seconds, p_kind, v_code, v_prompt, 'pending'
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.join_meet(p_code text)
returns public.social_meets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_row public.social_meets;
  v_norm text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  v_norm := upper(trim(p_code));
  select name into v_name from public.profiles where id = auth.uid();

  select * into v_row
  from public.social_meets
  where code = v_norm
  for update;

  if not found then
    raise exception 'Meet code not found.';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'Meet already claimed.';
  end if;
  if v_row.host_id = auth.uid() then
    raise exception 'You can''t join your own meet.';
  end if;

  update public.social_meets
  set guest_id = auth.uid(),
      guest_name = coalesce(v_name, ''),
      status = 'matched',
      matched_at = now()
  where id = v_row.id
  returning * into v_row;

  -- Guest receives the time the host poured (toast / entry stake).
  update public.profiles
  set time_balance_seconds = time_balance_seconds + v_row.seconds
  where id = auth.uid();

  return v_row;
end;
$$;

create or replace function public.complete_meet_icebreaker(p_meet_id uuid)
returns public.social_meets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.social_meets;
begin
  select * into v_row from public.social_meets where id = p_meet_id for update;
  if not found then
    raise exception 'Meet not found.';
  end if;
  if auth.uid() is distinct from v_row.host_id
     and auth.uid() is distinct from v_row.guest_id then
    raise exception 'Not a participant.';
  end if;
  if v_row.status = 'completed' then
    return v_row;
  end if;
  if v_row.status <> 'matched' then
    raise exception 'Meet is not matched yet.';
  end if;

  update public.social_meets
  set status = 'completed', completed_at = now()
  where id = p_meet_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.submit_duo_score(
  p_meet_id uuid,
  p_score int
)
returns public.social_meets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.social_meets;
  v_winner uuid;
begin
  if p_score < 0 then
    raise exception 'Invalid score.';
  end if;

  select * into v_row from public.social_meets where id = p_meet_id for update;
  if not found then
    raise exception 'Meet not found.';
  end if;
  if v_row.kind <> 'duo_beat' then
    raise exception 'Not a duo game.';
  end if;
  if v_row.status not in ('matched', 'completed') then
    raise exception 'Duo not ready.';
  end if;

  if auth.uid() = v_row.host_id then
    update public.social_meets set host_score = p_score where id = p_meet_id;
  elsif auth.uid() = v_row.guest_id then
    update public.social_meets set guest_score = p_score where id = p_meet_id;
  else
    raise exception 'Not a participant.';
  end if;

  select * into v_row from public.social_meets where id = p_meet_id;

  if v_row.host_score is not null and v_row.guest_score is not null then
    if v_row.host_score > v_row.guest_score then
      v_winner := v_row.host_id;
    elsif v_row.guest_score > v_row.host_score then
      v_winner := v_row.guest_id;
    else
      v_winner := null; -- draw
    end if;

    update public.social_meets
    set winner_id = v_winner,
        status = 'completed',
        completed_at = now()
    where id = p_meet_id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

create or replace function public.fetch_meet_by_code(p_code text)
returns public.social_meets
language sql
security definer
set search_path = public
stable
as $$
  select *
  from public.social_meets
  where code = upper(trim(p_code))
  limit 1;
$$;

grant execute on function public.set_open_to_meet(boolean, text, uuid, text) to authenticated;
grant execute on function public.list_whos_inside(text) to authenticated;
grant execute on function public.raise_meet(int, text) to authenticated;
grant execute on function public.join_meet(text) to authenticated;
grant execute on function public.complete_meet_icebreaker(uuid) to authenticated;
grant execute on function public.submit_duo_score(uuid, int) to authenticated;
grant execute on function public.fetch_meet_by_code(text) to authenticated;
