-- Fix chat listing + friends list for Chats button.

-- Avoid PL/pgSQL OUT-column clashes that can break list_friend_messages.
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
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;

  if not exists (
    select 1 from public.member_friendships mf
    where mf.member_id = auth.uid() and mf.friend_id = p_friend_id
  ) then
    raise exception 'Friend not found.';
  end if;

  update public.friend_messages fm
  set read_at = now()
  where fm.recipient_id = auth.uid()
    and fm.sender_id = p_friend_id
    and fm.read_at is null;

  update public.member_notifications n
  set read_at = now()
  where n.recipient_id = auth.uid()
    and n.sender_id = p_friend_id
    and n.kind = 'chat'
    and n.read_at is null;

  return query
  select
    m.id,
    m.sender_id,
    m.recipient_id,
    m.body,
    m.created_at,
    m.read_at,
    coalesce(p.name, 'Friend')::text as sender_name
  from public.friend_messages m
  left join public.profiles p on p.id = m.sender_id
  where (m.sender_id = auth.uid() and m.recipient_id = p_friend_id)
     or (m.sender_id = p_friend_id and m.recipient_id = auth.uid())
  order by m.created_at asc
  limit greatest(1, least(coalesce(p_limit, 80), 200));
end;
$$;

grant execute on function public.list_friend_messages(uuid, int) to authenticated;

create or replace function public.list_my_friends()
returns table (
  member_id uuid,
  display_name text,
  email text,
  branch text,
  vibe_tag text,
  is_nearby boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    mf.friend_id as member_id,
    coalesce(p.name, 'Friend') as display_name,
    coalesce(p.email, '') as email,
    coalesce(sp.branch, '') as branch,
    sp.vibe_tag,
    (sp.open_to_meet = true and sp.updated_at >= now() - interval '6 hours') as is_nearby
  from public.member_friendships mf
  join public.profiles p on p.id = mf.friend_id
  left join public.social_presence sp on sp.member_id = mf.friend_id
  where mf.member_id = auth.uid()
    and not public.has_member_block(auth.uid(), mf.friend_id)
  order by coalesce(p.name, 'Friend') asc;
$$;

grant execute on function public.list_my_friends() to authenticated;
