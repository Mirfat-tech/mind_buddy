create extension if not exists pgcrypto;

alter table public.user_devices
  add column if not exists device_model text,
  add column if not exists system_version text;

alter table if exists public.user_sessions
  add column if not exists device_model text,
  add column if not exists system_version text;

with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, device_id
      order by coalesce(last_seen, created_at, now()) desc, created_at desc, id desc
    ) as row_num
  from public.user_devices
  where user_id is not null
    and device_id is not null
    and btrim(device_id) <> ''
)
delete from public.user_devices d
using ranked r
where d.id = r.id
  and r.row_num > 1;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_sessions'
  ) then
    with ranked as (
      select
        id,
        row_number() over (
          partition by user_id, device_id
          order by coalesce(last_seen_at, last_seen, created_at, now()) desc, created_at desc, id desc
        ) as row_num
      from public.user_sessions
      where user_id is not null
        and device_id is not null
        and btrim(device_id) <> ''
    )
    delete from public.user_sessions s
    using ranked r
    where s.id = r.id
      and r.row_num > 1;
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_devices_user_device_unique'
      and conrelid = 'public.user_devices'::regclass
  ) then
    alter table public.user_devices
      add constraint user_devices_user_device_unique unique (user_id, device_id);
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'user_sessions'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'user_sessions_user_device_unique'
      and conrelid = 'public.user_sessions'::regclass
  ) then
    alter table public.user_sessions
      add constraint user_sessions_user_device_unique unique (user_id, device_id);
  end if;
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

  v_unlimited := v_tier not in ('light', 'full') or v_device_limit is null or v_device_limit < 0;

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
