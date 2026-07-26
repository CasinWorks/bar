-- Allow FCM device tokens (Firebase Cloud Messaging).

alter table public.device_push_tokens
  drop constraint if exists device_push_tokens_kind_check;

alter table public.device_push_tokens
  add constraint device_push_tokens_kind_check
  check (kind in ('fcm', 'apns', 'live_activity', 'live_activity_start'));
