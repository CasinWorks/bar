-- Invite-gated mobile app downloads (website unlock codes).
-- Separate from event guest invites (EVT-*). Admins mint codes; guests redeem
-- once (or up to max_redemptions) on /download to reveal iOS/Android links.

-- ---------------------------------------------------------------------------
-- 1. Codes table
-- ---------------------------------------------------------------------------

create table if not exists public.app_download_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  label text,
  note text,
  max_redemptions int,
  redemption_count int not null default 0,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_download_invites_code_format
    check (code ~ '^[A-Z0-9-]{4,32}$'),
  constraint app_download_invites_max_redemptions_positive
    check (max_redemptions is null or max_redemptions > 0),
  constraint app_download_invites_redemption_count_nonneg
    check (redemption_count >= 0)
);

create unique index if not exists app_download_invites_code_uidx
  on public.app_download_invites (code);

create index if not exists app_download_invites_active_idx
  on public.app_download_invites (created_at desc)
  where revoked_at is null;

create or replace function public.touch_app_download_invites_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_app_download_invites_updated_at
  on public.app_download_invites;
create trigger trg_app_download_invites_updated_at
  before update on public.app_download_invites
  for each row
  execute function public.touch_app_download_invites_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Code generator: BT- + 8 uppercase hex (collision-retried)
-- ---------------------------------------------------------------------------

create or replace function public.generate_app_download_invite_code()
returns text
language plpgsql
volatile
set search_path = pg_catalog, public
as $$
declare
  candidate text;
  i int;
begin
  for i in 1..12 loop
    candidate := 'BT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    begin
      if not exists (
        select 1 from public.app_download_invites where code = candidate
      ) then
        return candidate;
      end if;
    exception
      when insufficient_privilege then
        return candidate;
    end;
  end loop;
  return candidate;
end;
$$;

comment on function public.generate_app_download_invite_code() is
  'BT- + 8 uppercase hex. Collision-retried against app_download_invites.';

revoke all on function public.generate_app_download_invite_code() from public;
grant execute on function public.generate_app_download_invite_code() to service_role;
grant execute on function public.generate_app_download_invite_code() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Redeem (atomic). Returns ok jsonb; raises on invalid/exhausted codes.
-- ---------------------------------------------------------------------------

create or replace function public.redeem_app_download_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  normalized text;
  invite public.app_download_invites%rowtype;
begin
  normalized := upper(trim(coalesce(p_code, '')));
  if normalized = '' then
    raise exception 'Invite code is required.';
  end if;

  select * into invite
  from public.app_download_invites
  where code = normalized
  for update;

  if not found then
    raise exception 'Invalid invite code.';
  end if;

  if invite.revoked_at is not null then
    raise exception 'This invite code has been revoked.';
  end if;

  if invite.expires_at is not null and invite.expires_at <= now() then
    raise exception 'This invite code has expired.';
  end if;

  if invite.max_redemptions is not null
     and invite.redemption_count >= invite.max_redemptions then
    raise exception 'This invite code has no redemptions left.';
  end if;

  update public.app_download_invites
  set redemption_count = redemption_count + 1
  where id = invite.id;

  return jsonb_build_object(
    'ok', true,
    'code', invite.code,
    'redemption_count', invite.redemption_count + 1,
    'max_redemptions', invite.max_redemptions
  );
end;
$$;

revoke all on function public.redeem_app_download_invite(text) from public;
grant execute on function public.redeem_app_download_invite(text) to service_role;

comment on function public.redeem_app_download_invite(text) is
  'Atomically validates and redeems an app download invite. Service role only.';

-- ---------------------------------------------------------------------------
-- 4. RLS — no public reads; admins manage via policies; unlock uses service role
-- ---------------------------------------------------------------------------

alter table public.app_download_invites enable row level security;

drop policy if exists "app_download_invites_admin_all" on public.app_download_invites;
create policy "app_download_invites_admin_all"
  on public.app_download_invites for all
  using (public.is_admin_or_hr())
  with check (public.is_admin_or_hr());

-- ---------------------------------------------------------------------------
-- 5. Private storage bucket for Android APK (service-role signed URLs only)
-- ---------------------------------------------------------------------------
-- 50 MB is the per-file ceiling on the Supabase free plan, so a bucket limit
-- above it cannot be honoured. The universal (fat) APK is ~90 MB; upload the
-- per-ABI splits from `flutter build apk --split-per-abi` instead — arm64-v8a
-- lands around a third of that size and covers current Android hardware.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  false,
  52428800, -- 50 MB (free plan per-file max)
  array[
    'application/vnd.android.package-archive',
    'application/octet-stream'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- No storage.objects policies for anon/authenticated — only service role
-- can create signed download URLs after a successful invite redeem.
