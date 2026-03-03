-- Stable per-install device registration with idempotent upsert semantics.
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  platform text,
  device_name text,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_devices_user_device_unique'
      and conrelid = 'public.user_devices'::regclass
  ) then
    alter table public.user_devices
      add constraint user_devices_user_device_unique
      unique (user_id, device_id);
  end if;
end;
$$;

create index if not exists user_devices_user_last_seen_idx
  on public.user_devices (user_id, last_seen desc);

-- Backfill from legacy table when present.
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'user_sessions'
  ) then
    insert into public.user_devices (
      user_id,
      device_id,
      platform,
      device_name,
      created_at,
      last_seen
    )
    select
      s.user_id,
      s.device_id,
      s.platform,
      s.device_name,
      coalesce(s.last_seen_at, now()),
      coalesce(s.last_seen_at, now())
    from public.user_sessions s
    where s.user_id is not null
      and s.device_id is not null
    on conflict (user_id, device_id)
    do update set
      platform = excluded.platform,
      device_name = excluded.device_name,
      last_seen = greatest(public.user_devices.last_seen, excluded.last_seen);
  end if;
end;
$$;

alter table public.user_devices enable row level security;

drop policy if exists "Users can view their devices" on public.user_devices;
create policy "Users can view their devices"
  on public.user_devices for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their devices" on public.user_devices;
create policy "Users can insert their devices"
  on public.user_devices for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their devices" on public.user_devices;
create policy "Users can update their devices"
  on public.user_devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their devices" on public.user_devices;
create policy "Users can delete their devices"
  on public.user_devices for delete
  using (auth.uid() = user_id);

create or replace function public.user_tier(uid uuid)
returns text
language sql
stable
as $$
  with raw as (
    select lower(coalesce((select subscription_tier from public.profiles where id = uid), '')) as tier
  )
  select case
    when tier in ('full','full_support','full support','full_support_mode','full support mode') then 'full'
    when tier in ('light','light_support','light support','light_support_mode','light support mode') then 'light'
    else 'free'
  end
  from raw;
$$;

create or replace function public.device_limit(uid uuid)
returns int
language sql
stable
as $$
  select case public.user_tier(uid)
    when 'full' then coalesce(
      nullif(current_setting('app.full_device_limit', true), '')::int,
      5
    )
    when 'light' then 3
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
