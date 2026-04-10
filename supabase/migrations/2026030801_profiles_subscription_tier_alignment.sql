begin;

create or replace function public.normalize_subscription_tier(raw_tier text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(raw_tier, '')) = 'pending' then 'pending'
    when lower(coalesce(raw_tier, '')) in
      ('full', 'full_support', 'full support', 'full_support_mode', 'full support mode')
    then 'full'
    when lower(coalesce(raw_tier, '')) in
      ('plus', 'plus_support', 'plus support', 'plus_support_mode', 'plus support mode', 'pro', 'premium')
    then 'plus'
    when lower(coalesce(raw_tier, '')) in
      ('light', 'light_support', 'light support', 'light_support_mode', 'light support mode')
    then 'light'
    else 'free'
  end;
$$;

update public.profiles
set subscription_tier = public.normalize_subscription_tier(subscription_tier)
where subscription_tier is not null;

alter table if exists public.profiles
  drop constraint if exists profiles_subscription_tier_check;

alter table if exists public.profiles
  add constraint profiles_subscription_tier_check
  check (
    subscription_tier is null or
    lower(subscription_tier) in ('pending', 'free', 'light', 'plus', 'full')
  );

create or replace function public.get_user_entitlement(uid uuid)
returns table (
  subscription_tier text,
  subscription_status text,
  device_limit int
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_raw_tier text;
  v_raw_status text;
  v_tier text;
begin
  select u.email into v_email
  from auth.users u
  where u.id = uid;

  select p.subscription_tier, p.subscription_status
  into v_raw_tier, v_raw_status
  from public.profiles p
  where p.id = uid;

  if v_raw_tier is null and coalesce(v_email, '') <> '' then
    select p.subscription_tier, p.subscription_status
    into v_raw_tier, v_raw_status
    from public.profiles p
    where lower(coalesce(p.email, '')) = lower(v_email)
    limit 1;

    if v_raw_tier is not null then
      begin
        insert into public.profiles (id, email, subscription_tier, subscription_status)
        values (uid, v_email, v_raw_tier, coalesce(v_raw_status, 'active'))
        on conflict (id) do update
          set email = coalesce(excluded.email, public.profiles.email),
              subscription_tier = coalesce(excluded.subscription_tier, public.profiles.subscription_tier),
              subscription_status = coalesce(excluded.subscription_status, public.profiles.subscription_status);
      exception
        when others then
          null;
      end;
    end if;
  end if;

  v_tier := public.normalize_subscription_tier(v_raw_tier);

  subscription_tier := v_tier;
  subscription_status := case
    when lower(coalesce(v_raw_status, '')) in ('active', 'trialing') then 'active'
    when v_tier in ('light', 'plus', 'full') then 'active'
    else 'inactive'
  end;
  device_limit := case
    when v_tier = 'full' then coalesce(
      nullif(current_setting('app.full_device_limit', true), '')::int,
      10
    )
    when v_tier = 'plus' then 3
    when v_tier = 'light' then 1
    else null
  end;
  return next;
end;
$$;

create or replace function public.get_my_entitlement()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_ent record;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select * into v_ent
  from public.get_user_entitlement(v_uid);

  return jsonb_build_object(
    'subscription_tier', coalesce(v_ent.subscription_tier, 'free'),
    'subscription_status', coalesce(v_ent.subscription_status, 'inactive'),
    'device_limit', case
      when coalesce(v_ent.subscription_tier, 'free') in ('light', 'plus', 'full') then v_ent.device_limit
      else null
    end
  );
end;
$$;

create or replace function public.user_tier(uid uuid)
returns text
language sql
stable
as $$
  select coalesce((select subscription_tier from public.get_user_entitlement(uid)), 'free');
$$;

create or replace function public.device_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.user_tier(uid) in ('light', 'plus', 'full') then (select device_limit from public.get_user_entitlement(uid))
    else null
  end;
$$;

create or replace function public.set_my_subscription_plan(
  p_tier text,
  p_terms_version text default null,
  p_terms_accepted_at timestamptz default null,
  p_privacy_version text default null,
  p_privacy_accepted_at timestamptz default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_tier text := public.normalize_subscription_tier(p_tier);
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = v_uid;

  insert into public.profiles (
    id,
    email,
    subscription_tier,
    terms_version,
    terms_accepted_at,
    privacy_version,
    privacy_accepted_at
  )
  values (
    v_uid,
    v_email,
    v_tier,
    p_terms_version,
    p_terms_accepted_at,
    p_privacy_version,
    p_privacy_accepted_at
  )
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email),
        subscription_tier = excluded.subscription_tier,
        terms_version = coalesce(excluded.terms_version, public.profiles.terms_version),
        terms_accepted_at = coalesce(excluded.terms_accepted_at, public.profiles.terms_accepted_at),
        privacy_version = coalesce(excluded.privacy_version, public.profiles.privacy_version),
        privacy_accepted_at = coalesce(excluded.privacy_accepted_at, public.profiles.privacy_accepted_at)
  returning * into v_row;

  return v_row;
end;
$$;

alter function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) owner to postgres;
revoke all on function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) from public;
grant execute on function public.set_my_subscription_plan(text, text, timestamptz, text, timestamptz) to authenticated;

commit;
