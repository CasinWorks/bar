-- Device / Live Activity push tokens for friend pings, chat, and requests.
-- Remote delivery requires APNs secrets on the send-social-push Edge Function.

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'ios'
    check (platform in ('ios', 'android')),
  kind text not null default 'fcm'
    check (kind in ('fcm', 'apns', 'live_activity', 'live_activity_start')),
  token text not null,
  bundle_id text,
  environment text not null default 'sandbox'
    check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, kind, token)
);

create index if not exists device_push_tokens_user_idx
  on public.device_push_tokens (user_id, kind);

alter table public.device_push_tokens enable row level security;

drop policy if exists device_push_tokens_select_own on public.device_push_tokens;
create policy device_push_tokens_select_own
  on public.device_push_tokens for select
  using (auth.uid() = user_id);

drop policy if exists device_push_tokens_insert_own on public.device_push_tokens;
create policy device_push_tokens_insert_own
  on public.device_push_tokens for insert
  with check (auth.uid() = user_id);

drop policy if exists device_push_tokens_update_own on public.device_push_tokens;
create policy device_push_tokens_update_own
  on public.device_push_tokens for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists device_push_tokens_delete_own on public.device_push_tokens;
create policy device_push_tokens_delete_own
  on public.device_push_tokens for delete
  using (auth.uid() = user_id);

create or replace function public.register_push_token(
  p_token text,
  p_kind text default 'fcm',
  p_platform text default 'ios',
  p_bundle_id text default null,
  p_environment text default 'sandbox'
)
returns public.device_push_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.device_push_tokens;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated.';
  end if;
  if nullif(trim(p_token), '') is null then
    raise exception 'Token required.';
  end if;

  insert into public.device_push_tokens (
    user_id, platform, kind, token, bundle_id, environment, updated_at
  )
  values (
    auth.uid(),
    coalesce(nullif(trim(p_platform), ''), 'ios'),
    coalesce(nullif(trim(p_kind), ''), 'fcm'),
    trim(p_token),
    nullif(trim(p_bundle_id), ''),
    case
      when lower(coalesce(p_environment, 'sandbox')) = 'production' then 'production'
      else 'sandbox'
    end,
    now()
  )
  on conflict (user_id, kind, token) do update
    set platform = excluded.platform,
        bundle_id = excluded.bundle_id,
        environment = excluded.environment,
        updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.clear_push_token(p_token text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;
  if p_token is null or trim(p_token) = '' then
    delete from public.device_push_tokens where user_id = auth.uid();
  else
    delete from public.device_push_tokens
    where user_id = auth.uid() and token = trim(p_token);
  end if;
end;
$$;

grant execute on function public.register_push_token(text, text, text, text, text)
  to authenticated;
grant execute on function public.clear_push_token(text) to authenticated;

-- Queue row so Edge Function / webhook can fan out APNs (service role reads this).
create table if not exists public.push_dispatch_queue (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  source_table text,
  source_id uuid,
  created_at timestamptz not null default now(),
  dispatched_at timestamptz
);

create index if not exists push_dispatch_queue_pending_idx
  on public.push_dispatch_queue (created_at)
  where dispatched_at is null;

alter table public.push_dispatch_queue enable row level security;
-- No client policies — service role / edge function only.

create or replace function public.enqueue_social_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
  v_sender_name text;
begin
  select coalesce(nullif(trim(name), ''), 'Friend')
    into v_sender_name
  from public.profiles
  where id = new.sender_id;

  if new.kind = 'chat' then
    v_title := 'Message from ' || coalesce(v_sender_name, 'Friend');
    v_body := left(coalesce(new.message, ''), 120);
  elsif new.kind = 'friend_request' then
    v_title := 'Friend request';
    v_body := coalesce(v_sender_name, 'Someone') || ' wants to add you.';
  else
    v_title := 'Ping from ' || coalesce(v_sender_name, 'Friend');
    v_body := left(coalesce(new.message, 'I am here.'), 120);
  end if;

  insert into public.push_dispatch_queue (
    recipient_id, title, body, data, source_table, source_id
  ) values (
    new.recipient_id,
    v_title,
    v_body,
    jsonb_build_object(
      'kind', new.kind,
      'notification_id', new.id,
      'sender_id', new.sender_id,
      'sender_name', coalesce(v_sender_name, 'Friend')
    ),
    'member_notifications',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists member_notifications_enqueue_push on public.member_notifications;
create trigger member_notifications_enqueue_push
  after insert on public.member_notifications
  for each row
  execute function public.enqueue_social_push();

create or replace function public.enqueue_friend_request_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_name text;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  select coalesce(nullif(trim(name), ''), 'Someone')
    into v_sender_name
  from public.profiles
  where id = new.requester_id;

  insert into public.push_dispatch_queue (
    recipient_id, title, body, data, source_table, source_id
  ) values (
    new.recipient_id,
    'Friend request',
    coalesce(v_sender_name, 'Someone') || ' wants to add you.',
    jsonb_build_object(
      'kind', 'friend_request',
      'request_id', new.id,
      'sender_id', new.requester_id,
      'sender_name', coalesce(v_sender_name, 'Someone')
    ),
    'friend_requests',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists friend_requests_enqueue_push on public.friend_requests;
create trigger friend_requests_enqueue_push
  after insert on public.friend_requests
  for each row
  execute function public.enqueue_friend_request_push();

-- Delivery: POST https://<admin>/api/push/drain every minute (or Database Webhook
-- on push_dispatch_queue INSERT) with header x-push-secret = PUSH_WEBHOOK_SECRET.
-- Requires FIREBASE_SERVICE_ACCOUNT_JSON on the admin server (FCM path) and/or
-- APNs env on the Edge Function (see docs/FIREBASE_SETUP.md).
