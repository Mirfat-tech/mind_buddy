begin;

update public.profiles
set
  subscription_tier = 'plus',
  subscription_status = 'active',
  subscription_completed = true,
  completed_at = coalesce(completed_at, now())
where lower(coalesce(subscription_tier, '')) in (
  'full',
  'full_support',
  'full support',
  'full_support_mode',
  'full support mode',
  'light',
  'light_support',
  'light support',
  'light_support_mode',
  'light support mode'
);

insert into public.profiles (
  id,
  email,
  subscription_tier,
  subscription_status,
  subscription_completed,
  completed_at
)
select
  u.id,
  u.email,
  'plus',
  'active',
  true,
  now()
from auth.users u
where lower(coalesce(u.email, '')) = 'mirfatmohamed@icloud.com'
on conflict (id) do update
set
  email = coalesce(excluded.email, public.profiles.email),
  subscription_tier = 'plus',
  subscription_status = 'active',
  subscription_completed = true,
  completed_at = coalesce(public.profiles.completed_at, excluded.completed_at);

update public.profiles
set
  subscription_tier = 'plus',
  subscription_status = 'active',
  subscription_completed = true,
  completed_at = coalesce(completed_at, now())
where lower(coalesce(email, '')) = 'mirfatmohamed@icloud.com'
   or id in (
     select u.id
     from auth.users u
     where lower(coalesce(u.email, '')) = 'mirfatmohamed@icloud.com'
   );

commit;
