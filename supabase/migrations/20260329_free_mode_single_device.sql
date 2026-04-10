begin;

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
        values (uid, v_email, public.normalize_subscription_tier(v_raw_tier), coalesce(v_raw_status, 'active'))
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
    when v_tier in ('free', 'plus', 'full') then 'active'
    else 'inactive'
  end;
  device_limit := case
    when v_tier = 'full' then coalesce(
      nullif(current_setting('app.full_device_limit', true), '')::int,
      10
    )
    when v_tier = 'plus' then 3
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
      when coalesce(v_ent.subscription_tier, 'free') in ('free', 'plus', 'full') then v_ent.device_limit
      else null
    end
  );
end;
$$;

create or replace function public.device_limit(uid uuid)
returns int
language sql
stable
as $$
  select case
    when public.user_tier(uid) in ('free', 'plus', 'full') then (select device_limit from public.get_user_entitlement(uid))
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

commit;
