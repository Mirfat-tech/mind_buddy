-- Subscription-based limits and policies

create or replace function public.is_plus_support(uid uuid)
returns boolean
language sql
stable
as $$
  select public.normalize_subscription_tier(
    (select subscription_tier from public.profiles where id = uid)
  ) = 'plus';
$$;

create or replace function public.is_pending_support(uid uuid)
returns boolean
language sql
stable
as $$
  select public.normalize_subscription_tier(
    (select subscription_tier from public.profiles where id = uid)
  ) = 'pending';
$$;

create or replace function public.message_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.is_pending_support(uid) then 0
    when public.is_plus_support(uid) then 50
    else 0
  end;
$$;

create or replace function public.journal_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.is_pending_support(uid) then 0
    else -1
  end;
$$;

create or replace function public.device_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.is_plus_support(uid) then -1
    when public.normalize_subscription_tier(
      (select subscription_tier from public.profiles where id = uid)
    ) = 'free' then 1
    else null
  end;
$$;
