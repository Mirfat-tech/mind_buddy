-- Dashboard hotfix: device tables + RLS + entitlement RPC + idempotent register RPC.
-- Safe to run multiple times.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1) Canonical + legacy device tables (both present for app fallback behavior)
-- ---------------------------------------------------------------------------

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  platform text,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now()
);

create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  platform text,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.user_devices
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists last_seen timestamptz not null default now();

alter table public.user_sessions
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists last_seen timestamptz not null default now(),
  add column if not exists last_seen_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_devices_user_device_unique'
      and conrelid = 'public.user_devices'::regclass
  ) and to_regclass('public.user_devices_user_device_unique') is null then
    alter table public.user_devices
      add constraint user_devices_user_device_unique unique (user_id, device_id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'user_sessions_user_device_unique'
      and conrelid = 'public.user_sessions'::regclass
  ) and to_regclass('public.user_sessions_user_device_unique') is null then
    alter table public.user_sessions
      add constraint user_sessions_user_device_unique unique (user_id, device_id);
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'user_devices_user_device_unique'
      and conrelid = 'public.user_devices'::regclass
  ) then
    null;
  elsif to_regclass('public.user_devices_user_device_unique') is not null then
    raise notice
      'Skipping add constraint user_devices_user_device_unique because a relation with that name already exists.';
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'user_sessions_user_device_unique'
      and conrelid = 'public.user_sessions'::regclass
  ) then
    null;
  elsif to_regclass('public.user_sessions_user_device_unique') is not null then
    raise notice
      'Skipping add constraint user_sessions_user_device_unique because a relation with that name already exists.';
  end if;
end
$$;

create index if not exists user_devices_user_last_seen_idx
  on public.user_devices (user_id, last_seen desc);

create index if not exists user_sessions_user_last_seen_idx
  on public.user_sessions (user_id, last_seen desc);

create index if not exists user_sessions_user_last_seen_at_idx
  on public.user_sessions (user_id, last_seen_at desc);

-- Keep legacy timestamps synchronized.
create or replace function public.sync_user_sessions_seen_columns()
returns trigger
language plpgsql
as $$
begin
  if new.last_seen is null and new.last_seen_at is not null then
    new.last_seen := new.last_seen_at;
  end if;
  if new.last_seen_at is null and new.last_seen is not null then
    new.last_seen_at := new.last_seen;
  end if;
  if new.last_seen is null then
    new.last_seen := now();
  end if;
  if new.last_seen_at is null then
    new.last_seen_at := new.last_seen;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_user_sessions_sync_seen on public.user_sessions;
create trigger trg_user_sessions_sync_seen
before insert or update of last_seen, last_seen_at
on public.user_sessions
for each row
execute function public.sync_user_sessions_seen_columns();

-- ---------------------------------------------------------------------------
-- 2) RLS policies for both tables
-- ---------------------------------------------------------------------------

alter table public.user_devices enable row level security;
alter table public.user_sessions enable row level security;

drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own"
  on public.user_devices for select
  using (user_id = auth.uid());

drop policy if exists "user_devices_insert_own" on public.user_devices;
create policy "user_devices_insert_own"
  on public.user_devices for insert
  with check (user_id = auth.uid());

drop policy if exists "user_devices_update_own" on public.user_devices;
create policy "user_devices_update_own"
  on public.user_devices for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "user_devices_delete_own" on public.user_devices;
create policy "user_devices_delete_own"
  on public.user_devices for delete
  using (user_id = auth.uid());

drop policy if exists "user_sessions_select_own" on public.user_sessions;
create policy "user_sessions_select_own"
  on public.user_sessions for select
  using (user_id = auth.uid());

drop policy if exists "user_sessions_insert_own" on public.user_sessions;
create policy "user_sessions_insert_own"
  on public.user_sessions for insert
  with check (user_id = auth.uid());

drop policy if exists "user_sessions_update_own" on public.user_sessions;
create policy "user_sessions_update_own"
  on public.user_sessions for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "user_sessions_delete_own" on public.user_sessions;
create policy "user_sessions_delete_own"
  on public.user_sessions for delete
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3) Profiles linkage + RLS + signup trigger
-- ---------------------------------------------------------------------------

alter table if exists public.profiles
  add column if not exists email text,
  add column if not exists subscription_tier text,
  add column if not exists subscription_status text;

alter table if exists public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

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

-- ---------------------------------------------------------------------------
-- 4) Entitlement RPCs (RLS-safe) + tier/limit helpers
-- ---------------------------------------------------------------------------

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

  select p.subscription_tier, p.subscription_status
  into v_raw_tier, v_raw_status
  from public.profiles p
  where p.id = uid;

  -- Recovery if old profile row used wrong UUID but correct email.
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

-- ---------------------------------------------------------------------------
-- 5) Device registration RPC (uses auth.uid internally, idempotent upsert)
-- ---------------------------------------------------------------------------

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
  v_unlimited boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select subscription_tier, subscription_status, device_limit
  into v_tier, v_status, v_device_limit
  from public.get_user_entitlement(v_user_id);

  v_unlimited := v_tier not in ('light', 'full') or v_device_limit is null or v_device_limit < 0;

  -- Existing device: always update and allow.
  update public.user_devices
  set
    platform = coalesce(p_platform, platform),
    device_name = coalesce(p_device_name, device_name),
    last_seen = now()
  where user_id = v_user_id
    and device_id = p_device_id;

  if found then
    select count(*) into v_device_count from public.user_devices where user_id = v_user_id;
    return jsonb_build_object(
      'allowed', true,
      'reused', true,
      'tier', v_tier,
      'subscription_status', v_status,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  select count(*) into v_device_count from public.user_devices where user_id = v_user_id;
  if v_unlimited or v_device_count < v_device_limit then
    insert into public.user_devices (user_id, device_id, platform, device_name, created_at, last_seen)
    values (v_user_id, p_device_id, p_platform, p_device_name, now(), now())
    on conflict (user_id, device_id) do update
      set platform = excluded.platform,
          device_name = excluded.device_name,
          last_seen = excluded.last_seen;

    select count(*) into v_device_count from public.user_devices where user_id = v_user_id;
    return jsonb_build_object(
      'allowed', true,
      'reused', false,
      'tier', v_tier,
      'subscription_status', v_status,
      'device_count', v_device_count,
      'device_limit', v_device_limit
    );
  end if;

  return jsonb_build_object(
    'allowed', false,
    'error_code', 'device_limit_reached',
    'tier', v_tier,
    'subscription_status', v_status,
    'device_count', v_device_count,
    'device_limit', v_device_limit
  );
end;
$$;

revoke all on function public.register_user_device(text, text, text) from public;
grant execute on function public.register_user_device(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Backfill between legacy/current tables so UI always has data
-- ---------------------------------------------------------------------------

insert into public.user_devices (user_id, device_id, device_name, platform, created_at, last_seen)
select
  s.user_id,
  s.device_id,
  s.device_name,
  s.platform,
  coalesce(s.created_at, now()),
  coalesce(s.last_seen, s.last_seen_at, now())
from public.user_sessions s
on conflict (user_id, device_id) do update
  set device_name = excluded.device_name,
      platform = excluded.platform,
      last_seen = greatest(public.user_devices.last_seen, excluded.last_seen);

insert into public.user_sessions (user_id, device_id, device_name, platform, created_at, last_seen, last_seen_at)
select
  d.user_id,
  d.device_id,
  d.device_name,
  d.platform,
  coalesce(d.created_at, now()),
  coalesce(d.last_seen, now()),
  coalesce(d.last_seen, now())
from public.user_devices d
on conflict (user_id, device_id) do update
  set device_name = excluded.device_name,
      platform = excluded.platform,
      last_seen = greatest(public.user_sessions.last_seen, excluded.last_seen),
      last_seen_at = greatest(public.user_sessions.last_seen_at, excluded.last_seen_at);
