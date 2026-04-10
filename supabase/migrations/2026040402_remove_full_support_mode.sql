begin;

update public.profiles
set subscription_tier = 'plus'
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

create or replace function public.normalize_subscription_tier(raw_tier text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(raw_tier, '')) = 'pending' then 'pending'
    when lower(coalesce(raw_tier, '')) in
      (
        'plus',
        'plus_support',
        'plus support',
        'plus_support_mode',
        'plus support mode',
        'light',
        'light_support',
        'light support',
        'light_support_mode',
        'light support mode',
        'full',
        'full_support',
        'full support',
        'full_support_mode',
        'full support mode',
        'pro',
        'premium'
      )
    then 'plus'
    else 'free'
  end;
$$;

alter table if exists public.profiles
  drop constraint if exists profiles_subscription_tier_check;

alter table if exists public.profiles
  add constraint profiles_subscription_tier_check
  check (
    subscription_tier is null or
    lower(subscription_tier) in ('pending', 'free', 'plus')
  );

update public.profiles
set
  subscription_tier = public.normalize_subscription_tier(subscription_tier),
  subscription_status = case
    when public.normalize_subscription_tier(subscription_tier) = 'pending' then 'inactive'
    else 'active'
  end,
  subscription_completed = coalesce(subscription_completed, false) or
    public.normalize_subscription_tier(subscription_tier) in ('free', 'plus'),
  completed_at = case
    when completed_at is null
      and public.normalize_subscription_tier(subscription_tier) in ('free', 'plus')
    then now()
    else completed_at
  end
where subscription_tier is not null;

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
        values (
          uid,
          v_email,
          public.normalize_subscription_tier(v_raw_tier),
          case
            when public.normalize_subscription_tier(v_raw_tier) = 'pending' then 'inactive'
            else 'active'
          end
        )
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
    when v_tier = 'pending' then 'inactive'
    else 'active'
  end;
  device_limit := case
    when v_tier = 'plus' then -1
    when v_tier = 'free' then 1
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
      when coalesce(v_ent.subscription_tier, 'free') in ('free', 'plus') then v_ent.device_limit
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
    when public.user_tier(uid) in ('free', 'plus') then (select device_limit from public.get_user_entitlement(uid))
    else null
  end;
$$;

create or replace function public.register_user_device(
  p_device_id text,
  p_platform text default null,
  p_device_name text default null,
  p_device_model text default null,
  p_system_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_tier text := 'free';
  v_device_limit int := null;
  v_device_count int := 0;
  v_reclaimed boolean := false;
  v_unlimited boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select public.user_tier(v_user_id), public.device_limit(v_user_id)
  into v_tier, v_device_limit;

  v_unlimited := v_device_limit is null or v_device_limit < 0;

  update public.user_devices
  set
    platform = coalesce(p_platform, platform),
    device_name = coalesce(p_device_name, device_name),
    device_model = coalesce(p_device_model, device_model),
    system_version = coalesce(p_system_version, system_version),
    last_seen = now()
  where user_id = v_user_id
    and device_id = p_device_id;

  if found then
    select count(*) into v_device_count
    from public.user_devices
    where user_id = v_user_id;

    return jsonb_build_object(
      'allowed', true,
      'reused', true,
      'reclaimed', false,
      'tier', v_tier,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  select count(*) into v_device_count
  from public.user_devices
  where user_id = v_user_id;

  if not v_unlimited and v_device_count >= v_device_limit and v_device_limit = 1 then
    delete from public.user_devices
    where id in (
      select id
      from public.user_devices
      where user_id = v_user_id
        and last_seen < now() - interval '30 days'
      order by last_seen asc
      limit 1
    );

    if found then
      v_reclaimed := true;
      select count(*) into v_device_count
      from public.user_devices
      where user_id = v_user_id;
    end if;
  end if;

  if v_unlimited or v_device_count < v_device_limit then
    insert into public.user_devices (
      user_id,
      device_id,
      platform,
      device_name,
      device_model,
      system_version,
      created_at,
      last_seen
    )
    values (
      v_user_id,
      p_device_id,
      p_platform,
      p_device_name,
      p_device_model,
      p_system_version,
      now(),
      now()
    )
    on conflict (user_id, device_id)
    do update set
      platform = coalesce(excluded.platform, public.user_devices.platform),
      device_name = coalesce(excluded.device_name, public.user_devices.device_name),
      device_model = coalesce(excluded.device_model, public.user_devices.device_model),
      system_version = coalesce(excluded.system_version, public.user_devices.system_version),
      last_seen = excluded.last_seen;

    select count(*) into v_device_count
    from public.user_devices
    where user_id = v_user_id;

    return jsonb_build_object(
      'allowed', true,
      'reused', false,
      'reclaimed', v_reclaimed,
      'tier', v_tier,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  return jsonb_build_object(
    'allowed', false,
    'tier', v_tier,
    'error_code', 'device_limit_reached',
    'device_count', v_device_count,
    'device_limit', v_device_limit,
    'devices',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'device_id', d.device_id,
              'device_name', d.device_name,
              'platform', d.platform,
              'device_model', d.device_model,
              'system_version', d.system_version,
              'last_seen', d.last_seen
            )
            order by d.last_seen desc
          )
          from public.user_devices d
          where d.user_id = v_user_id
        ),
        '[]'::jsonb
      )
  );
end;
$$;

revoke all on function public.register_user_device(text, text, text, text, text) from public;
grant execute on function public.register_user_device(text, text, text, text, text) to authenticated;

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
    subscription_status,
    subscription_completed,
    completed_at,
    terms_version,
    terms_accepted_at,
    privacy_version,
    privacy_accepted_at
  )
  values (
    v_uid,
    v_email,
    v_tier,
    case when v_tier = 'pending' then 'inactive' else 'active' end,
    true,
    now(),
    p_terms_version,
    p_terms_accepted_at,
    p_privacy_version,
    p_privacy_accepted_at
  )
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email),
        subscription_tier = excluded.subscription_tier,
        subscription_status = excluded.subscription_status,
        subscription_completed = true,
        completed_at = coalesce(public.profiles.completed_at, excluded.completed_at),
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
