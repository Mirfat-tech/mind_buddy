begin;

alter table if exists public.user_devices
  add column if not exists is_active boolean not null default true,
  add column if not exists signed_out_at timestamptz,
  add column if not exists revoked_at timestamptz;

alter table if exists public.user_sessions
  add column if not exists is_active boolean not null default true,
  add column if not exists signed_out_at timestamptz,
  add column if not exists revoked_at timestamptz;

update public.user_devices
set is_active = true
where is_active is distinct from true
  and signed_out_at is null
  and revoked_at is null;

update public.user_sessions
set is_active = true
where is_active is distinct from true
  and signed_out_at is null
  and revoked_at is null;

create index if not exists user_devices_user_active_last_seen_idx
  on public.user_devices (user_id, is_active, last_seen desc);

create index if not exists user_sessions_user_active_last_seen_idx
  on public.user_sessions (user_id, is_active, last_seen_at desc);

create or replace function public.sign_out_everywhere()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_revoked_session_count integer := 0;
  v_marked_inactive_device_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  update public.user_sessions
  set
    is_active = false,
    signed_out_at = coalesce(signed_out_at, v_now),
    revoked_at = coalesce(revoked_at, v_now),
    last_seen = coalesce(last_seen, last_seen_at, v_now),
    last_seen_at = coalesce(last_seen_at, last_seen, v_now)
  where user_id = v_user_id
    and (
      is_active is distinct from false
      or signed_out_at is null
      or revoked_at is null
    );

  get diagnostics v_revoked_session_count = row_count;

  update public.user_devices
  set
    is_active = false,
    signed_out_at = coalesce(signed_out_at, v_now),
    revoked_at = coalesce(revoked_at, v_now),
    last_seen = coalesce(last_seen, v_now)
  where user_id = v_user_id
    and (
      is_active is distinct from false
      or signed_out_at is null
      or revoked_at is null
    );

  get diagnostics v_marked_inactive_device_count = row_count;

  return jsonb_build_object(
    'revoked_session_count', v_revoked_session_count,
    'marked_inactive_device_count', v_marked_inactive_device_count
  );
end;
$$;

revoke all on function public.sign_out_everywhere() from public;
grant execute on function public.sign_out_everywhere() to authenticated;

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
  v_device_id text := nullif(btrim(p_device_id), '');
  v_tier text := 'free';
  v_device_limit int := null;
  v_device_count int := 0;
  v_reclaimed boolean := false;
  v_unlimited boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if v_device_id is null then
    raise exception 'Device id required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_user_id::text || ':' || v_device_id));

  select public.user_tier(v_user_id), public.device_limit(v_user_id)
  into v_tier, v_device_limit;

  v_unlimited := v_device_limit is null or v_device_limit < 0;

  update public.user_devices
  set
    platform = coalesce(p_platform, platform),
    device_name = coalesce(p_device_name, device_name),
    device_model = coalesce(p_device_model, device_model),
    system_version = coalesce(p_system_version, system_version),
    last_seen = now(),
    is_active = true,
    signed_out_at = null,
    revoked_at = null
  where user_id = v_user_id
    and device_id = v_device_id;

  insert into public.user_sessions (
    user_id,
    device_id,
    platform,
    device_name,
    created_at,
    last_seen,
    last_seen_at,
    is_active,
    signed_out_at,
    revoked_at
  )
  values (
    v_user_id,
    v_device_id,
    p_platform,
    p_device_name,
    now(),
    now(),
    now(),
    true,
    null,
    null
  )
  on conflict (user_id, device_id)
  do update set
    platform = coalesce(excluded.platform, public.user_sessions.platform),
    device_name = coalesce(excluded.device_name, public.user_sessions.device_name),
    last_seen = excluded.last_seen,
    last_seen_at = excluded.last_seen_at,
    is_active = true,
    signed_out_at = null,
    revoked_at = null;

  if exists (
    select 1
    from public.user_devices
    where user_id = v_user_id
      and device_id = v_device_id
  ) then
    select count(distinct device_id) into v_device_count
    from public.user_devices
    where user_id = v_user_id
      and coalesce(is_active, true) = true
      and signed_out_at is null
      and revoked_at is null;

    return jsonb_build_object(
      'allowed', true,
      'reused', true,
      'reclaimed', false,
      'tier', v_tier,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  select count(distinct device_id) into v_device_count
  from public.user_devices
  where user_id = v_user_id
    and coalesce(is_active, true) = true
    and signed_out_at is null
    and revoked_at is null;

  if not v_unlimited and v_device_count >= v_device_limit and v_device_limit = 1 then
    update public.user_devices
    set
      is_active = false,
      signed_out_at = coalesce(signed_out_at, now()),
      revoked_at = coalesce(revoked_at, now())
    where id in (
      select id
      from public.user_devices
      where user_id = v_user_id
        and coalesce(is_active, true) = true
        and last_seen < now() - interval '30 days'
      order by last_seen asc
      limit 1
    );

    if found then
      update public.user_sessions
      set
        is_active = false,
        signed_out_at = coalesce(signed_out_at, now()),
        revoked_at = coalesce(revoked_at, now())
      where user_id = v_user_id
        and device_id in (
          select device_id
          from public.user_devices
          where user_id = v_user_id
            and coalesce(is_active, true) = false
            and revoked_at is not null
        );

      v_reclaimed := true;
      select count(distinct device_id) into v_device_count
      from public.user_devices
      where user_id = v_user_id
        and coalesce(is_active, true) = true
        and signed_out_at is null
        and revoked_at is null;
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
      last_seen,
      is_active,
      signed_out_at,
      revoked_at
    )
    values (
      v_user_id,
      v_device_id,
      p_platform,
      p_device_name,
      p_device_model,
      p_system_version,
      now(),
      now(),
      true,
      null,
      null
    )
    on conflict (user_id, device_id)
    do update set
      platform = coalesce(excluded.platform, public.user_devices.platform),
      device_name = coalesce(excluded.device_name, public.user_devices.device_name),
      device_model = coalesce(excluded.device_model, public.user_devices.device_model),
      system_version = coalesce(excluded.system_version, public.user_devices.system_version),
      last_seen = excluded.last_seen,
      is_active = true,
      signed_out_at = null,
      revoked_at = null;

    select count(distinct device_id) into v_device_count
    from public.user_devices
    where user_id = v_user_id
      and coalesce(is_active, true) = true
      and signed_out_at is null
      and revoked_at is null;

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
              'last_seen', d.last_seen,
              'is_active', d.is_active,
              'signed_out_at', d.signed_out_at,
              'revoked_at', d.revoked_at
            )
            order by d.last_seen desc
          )
          from public.user_devices d
          where d.user_id = v_user_id
            and coalesce(d.is_active, true) = true
            and d.signed_out_at is null
            and d.revoked_at is null
        ),
        '[]'::jsonb
      )
  );
end;
$$;

revoke all on function public.register_user_device(text, text, text, text, text) from public;
grant execute on function public.register_user_device(text, text, text, text, text) to authenticated;

commit;
