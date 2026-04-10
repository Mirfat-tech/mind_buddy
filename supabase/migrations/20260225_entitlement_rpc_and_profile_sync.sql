-- Entitlement lookup and profile linkage hardening.

alter table if exists public.profiles
  add column if not exists email text,
  add column if not exists subscription_tier text,
  add column if not exists subscription_status text;

-- Keep profile id aligned with auth user id for future signups.
create or replace function public.handle_new_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, email, subscription_tier, subscription_status)
  values (new.id, new.email, 'free', 'inactive')
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email);
  return new;
end;
$$;

alter function public.handle_new_auth_user_profile() owner to postgres;

do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'drop trigger if exists trg_auth_users_create_profile on auth.users';
    execute 'create trigger trg_auth_users_create_profile after insert on auth.users for each row execute function public.handle_new_auth_user_profile()';
  end if;
end
$$;

-- Basic self-access policies for direct profile reads/updates.
alter table if exists public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (id = auth.uid());

create or replace function public.normalize_subscription_tier(raw_tier text)
returns text
language sql
immutable
as $$
  select case
    when lower(coalesce(raw_tier, '')) in
      ('full', 'full_support', 'full support', 'full_support_mode', 'full support mode')
    then 'full'
    when lower(coalesce(raw_tier, '')) in
      ('light', 'light_support', 'light support', 'light_support_mode', 'light support mode')
    then 'light'
    else 'free'
  end;
$$;

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

  -- Primary lookup by canonical key.
  select p.subscription_tier, p.subscription_status
  into v_raw_tier, v_raw_status
  from public.profiles p
  where p.id = uid;

  -- Recovery path for historically mismatched profile IDs.
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
          -- Never fail entitlement lookup due to migration/constraint noise.
          null;
      end;
    end if;
  end if;

  v_tier := public.normalize_subscription_tier(v_raw_tier);

  subscription_tier := v_tier;
  subscription_status := case
    when lower(coalesce(v_raw_status, '')) in ('active', 'trialing') then 'active'
    when v_tier in ('light', 'full') then 'active'
    else 'inactive'
  end;
  device_limit := case
    when v_tier = 'full' then coalesce(
      nullif(current_setting('app.full_device_limit', true), '')::int,
      5
    )
    when v_tier = 'light' then 3
    else null
  end;
  return next;
end;
$$;

revoke all on function public.get_user_entitlement(uuid) from public;
grant execute on function public.get_user_entitlement(uuid) to authenticated;

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
      when coalesce(v_ent.subscription_tier, 'free') in ('light', 'full') then v_ent.device_limit
      else null
    end
  );
end;
$$;

revoke all on function public.get_my_entitlement() from public;
grant execute on function public.get_my_entitlement() to authenticated;

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
    when public.user_tier(uid) in ('light', 'full') then (select device_limit from public.get_user_entitlement(uid))
    else null
  end;
$$;

create or replace function public.register_user_device(
  p_device_id text,
  p_platform text default null,
  p_device_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_tier text := 'free';
  v_status text := 'inactive';
  v_device_limit int := null;
  v_device_count int := 0;
  v_reclaimed boolean := false;
  v_unlimited boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select
    subscription_tier,
    subscription_status,
    device_limit
  into
    v_tier,
    v_status,
    v_device_limit
  from public.get_user_entitlement(v_user_id);

  v_unlimited := v_tier not in ('light', 'full') or v_device_limit is null or v_device_limit < 0;

  update public.user_devices
  set
    platform = coalesce(p_platform, platform),
    device_name = coalesce(p_device_name, device_name),
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
      'subscription_status', v_status,
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
      created_at,
      last_seen
    )
    values (
      v_user_id,
      p_device_id,
      p_platform,
      p_device_name,
      now(),
      now()
    )
    on conflict (user_id, device_id)
    do update set
      platform = excluded.platform,
      device_name = excluded.device_name,
      last_seen = excluded.last_seen;

    select count(*) into v_device_count
    from public.user_devices
    where user_id = v_user_id;

    return jsonb_build_object(
      'allowed', true,
      'reused', false,
      'reclaimed', v_reclaimed,
      'tier', v_tier,
      'subscription_status', v_status,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  return jsonb_build_object(
    'allowed', false,
    'tier', v_tier,
    'subscription_status', v_status,
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

revoke all on function public.register_user_device(text, text, text) from public;
grant execute on function public.register_user_device(text, text, text) to authenticated;
