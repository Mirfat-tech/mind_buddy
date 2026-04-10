alter table if exists public.profiles
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists username_completed boolean not null default false,
  add column if not exists subscription_completed boolean not null default false,
  add column if not exists completed_at timestamptz;

update public.profiles
set username_completed = true
where coalesce(nullif(trim(username), ''), '') <> '';

update public.profiles
set subscription_completed = true
where lower(coalesce(subscription_tier, '')) in ('free', 'light', 'plus', 'full');

update public.profiles
set onboarding_completed = true
where onboarding_completed = false
  and (username_completed = true or subscription_completed = true);

update public.profiles
set completed_at = now()
where completed_at is null
  and onboarding_completed = true
  and username_completed = true
  and subscription_completed = true;
