-- Friend ping inbox + 1:1 chat + execute grants for friend/safety RPCs.

-- ---------------------------------------------------------------------------
-- Grants (013 RPCs were missing EXECUTE for authenticated)
-- ---------------------------------------------------------------------------
grant execute on function public.search_friend_candidates(text) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.decline_friend_request(uuid) to authenticated;
grant execute on function public.list_friend_requests() to authenticated;
grant execute on function public.list_mutual_friends_nearby(text) to authenticated;
grant execute on function public.notify_friend(uuid, text) to authenticated;
grant execute on function public.block_member(uuid, text) to authenticated;
grant execute on function public.unblock_member(uuid) to authenticated;
grant execute on function public.submit_safety_report(text, text, uuid, text, uuid) to authenticated;
grant execute on function public.request_ride_assist(text, text, text, text) to authenticated;
grant execute on function public.create_insurance_incident(text, uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Are we friends?
-- ---------------------------------------------------------------------------
create or replace function public.are_friends(p_other_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.member_friendships
    where member_id = auth.uid()
      and friend_id = p_other_id
  )
  and not public.has_member_block(auth.uid(), p_other_id);
$$;

grant execute on function public.are_friends(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Incoming friend pings / notifications
-- ---------------------------------------------------------------------------
create or replace function public.list_friend_notifications(
  p_unread_only boolean default false,
  p_limit int default 30
)
returns table (
  id uuid,
  sender_id uuid,
  recipient_id uuid,
  kind text,
  message text,
  created_at timestamptz,
  read_at timestamptz,
  sender_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.id,
    n.sender_id,
    n.recipient_id,
    n.kind,
    n.message,
    n.created_at,
    n.read_at,
    coalesce(p.name, 'Friend') as sender_name
  from public.member_notifications n
  left join public.profiles p on p.id = n.sender_id
  where n.recipient_id = auth.uid()
    and n.kind in ('friend_ping', 'chat')
    and (not p_unread_only or n.read_at is null)
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

grant execute on function public.list_friend_notifications(boolean, int) to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.member_notifications
  set read_at = now()
  where id = p_notification_id
    and recipient_id = auth.uid()
    and read_at is null;
  return found;
end;
$$;

grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_friend_pings_read()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  update public.member_notifications
  set read_at = now()
  where recipient_id = auth.uid()
    and kind = 'friend_ping'
    and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.mark_all_friend_pings_read() to authenticated;

-- ---------------------------------------------------------------------------
-- Friend chat messages
-- ---------------------------------------------------------------------------
create table if not exists public.friend_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint friend_messages_body_len check (char_length(trim(body)) between 1 and 500)
);

create index if not exists friend_messages_thread_idx
  on public.friend_messages (
    least(sender_id, recipient_id),
    greatest(sender_id, recipient_id),
    created_at desc
  );

alter table public.friend_messages enable row level security;

drop policy if exists "friend_messages_select_self" on public.friend_messages;
create policy "friend_messages_select_self"
  on public.friend_messages for select
  using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists "friend_messages_no_direct_insert" on public.friend_messages;
create policy "friend_messages_no_direct_insert"
  on public.friend_messages for insert
  with check (false);

create or replace function public.send_friend_message(p_friend_id uuid, p_body text)
returns public.friend_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.friend_messages;
  v_body text := trim(coalesce(p_body, ''));
begin
  if char_length(v_body) < 1 then
    raise exception 'Message is empty.';
  end if;
  if not exists (
    select 1 from public.member_friendships
    where member_id = auth.uid() and friend_id = p_friend_id
  ) then
    raise exception 'Friend not found.';
  end if;
  if public.has_member_block(auth.uid(), p_friend_id) then
    raise exception 'Chat unavailable.';
  end if;

  insert into public.friend_messages (sender_id, recipient_id, body)
  values (auth.uid(), p_friend_id, left(v_body, 500))
  returning * into v_row;

  -- Mirror a lightweight ping so inbox polling can surface unread chats.
  insert into public.member_notifications (sender_id, recipient_id, kind, message, metadata)
  values (
    auth.uid(),
    p_friend_id,
    'chat',
    left(v_body, 120),
    jsonb_build_object('message_id', v_row.id)
  );

  return v_row;
end;
$$;

grant execute on function public.send_friend_message(uuid, text) to authenticated;

create or replace function public.list_friend_messages(p_friend_id uuid, p_limit int default 80)
returns table (
  id uuid,
  sender_id uuid,
  recipient_id uuid,
  body text,
  created_at timestamptz,
  read_at timestamptz,
  sender_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.member_friendships
    where member_id = auth.uid() and friend_id = p_friend_id
  ) then
    raise exception 'Friend not found.';
  end if;

  update public.friend_messages
  set read_at = now()
  where recipient_id = auth.uid()
    and sender_id = p_friend_id
    and read_at is null;

  update public.member_notifications
  set read_at = now()
  where recipient_id = auth.uid()
    and sender_id = p_friend_id
    and kind = 'chat'
    and read_at is null;

  return query
  select
    m.id,
    m.sender_id,
    m.recipient_id,
    m.body,
    m.created_at,
    m.read_at,
    coalesce(p.name, 'Friend') as sender_name
  from public.friend_messages m
  left join public.profiles p on p.id = m.sender_id
  where (m.sender_id = auth.uid() and m.recipient_id = p_friend_id)
     or (m.sender_id = p_friend_id and m.recipient_id = auth.uid())
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 80), 200));
end;
$$;

grant execute on function public.list_friend_messages(uuid, int) to authenticated;

-- Realtime so phones can optionally subscribe later
do $$
begin
  begin
    alter publication supabase_realtime add table public.member_notifications;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.friend_messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.friend_requests;
  exception when duplicate_object then null;
  end;
end $$;
