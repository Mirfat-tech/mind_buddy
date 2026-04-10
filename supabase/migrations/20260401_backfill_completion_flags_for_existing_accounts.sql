begin;

update public.profiles
set username_completed = true
where coalesce(username_completed, false) = false
  and coalesce(nullif(trim(username), ''), '') <> '';

update public.profiles
set subscription_completed = true
where coalesce(subscription_completed, false) = false
  and (
    lower(coalesce(subscription_tier, '')) in ('free', 'light', 'plus', 'full')
    or coalesce(nullif(trim(username), ''), '') <> ''
  );

update public.profiles
set onboarding_completed = true
where coalesce(onboarding_completed, false) = false
  and (
    coalesce(username_completed, false) = true
    or coalesce(subscription_completed, false) = true
    or lower(coalesce(subscription_tier, '')) in ('free', 'light', 'plus', 'full')
    or coalesce(nullif(trim(username), ''), '') <> ''
  );

update public.profiles
set completed_at = coalesce(completed_at, now())
where onboarding_completed = true
  or username_completed = true
  or subscription_completed = true;

commit;
