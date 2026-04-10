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

select
  p.id,
  p.email,
  p.subscription_tier,
  p.subscription_status,
  public.get_user_entitlement(p.id)
from public.profiles p
where lower(coalesce(p.email, '')) = 'mirfatmohamed@icloud.com';
