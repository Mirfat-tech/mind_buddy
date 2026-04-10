-- Catch-up migration for environments missing expected runtime columns.

alter table if exists public.user_sessions
  add column if not exists last_seen timestamptz,
  add column if not exists last_seen_at timestamptz;

update public.user_sessions
set last_seen = coalesce(last_seen, last_seen_at, now())
where last_seen is null;

update public.user_sessions
set last_seen_at = coalesce(last_seen_at, last_seen, now())
where last_seen_at is null;

alter table if exists public.user_sessions
  alter column last_seen set default now(),
  alter column last_seen_at set default now();

alter table if exists public.profiles
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists username_completed boolean not null default false,
  add column if not exists subscription_completed boolean not null default false,
  add column if not exists completed_at timestamptz;
