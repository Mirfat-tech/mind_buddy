-- OAuth signup hardening: prevent auth.users insert failures from profile sync.
-- Safe to run multiple times.

begin;

-- Ensure expected profile columns exist.
alter table if exists public.profiles
  add column if not exists email text,
  add column if not exists full_name text,
  add column if not exists avatar_url text;

-- OAuth users may not have app-specific required fields at signup time.
-- Relax NOT NULL on non-key profile fields so profile sync can't break auth.
do $$
declare
  col text;
begin
  foreach col in array array[
    'email',
    'full_name',
    'avatar_url',
    'subscription_tier',
    'subscription_status',
    'username',
    'date_of_birth'
  ]
  loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = col
        and is_nullable = 'NO'
    ) then
      execute format(
        'alter table public.profiles alter column %I drop not null',
        col
      );
    end if;
  end loop;
end $$;

-- Canonical, safe profile creation trigger function.
create or replace function public.handle_new_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_full_name text;
  v_avatar_url text;
begin
  v_full_name := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name'
  );
  v_avatar_url := coalesce(
    new.raw_user_meta_data ->> 'avatar_url',
    new.raw_user_meta_data ->> 'picture'
  );

  insert into public.profiles (id, email, full_name, avatar_url)
  values (new.id, new.email, v_full_name, v_avatar_url)
  on conflict (id) do nothing;

  return new;
exception
  when others then
    -- Never block auth user creation because of profile sync issues.
    raise warning
      'handle_new_auth_user_profile failed for user %, sqlstate=%, error=%',
      new.id, sqlstate, sqlerrm;
    return new;
end;
$$;

alter function public.handle_new_auth_user_profile() owner to postgres;

-- Remove older/conflicting profile creation triggers on auth.users.
do $$
declare
  r record;
begin
  if to_regclass('auth.users') is null then
    return;
  end if;

  for r in
    select t.tgname
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace n on n.oid = p.pronamespace
    where t.tgrelid = 'auth.users'::regclass
      and not t.tgisinternal
      and n.nspname = 'public'
      and p.proname in (
        'handle_new_auth_user_profile',
        'handle_new_user',
        'create_profile_for_new_user'
      )
  loop
    execute format('drop trigger if exists %I on auth.users', r.tgname);
  end loop;

  execute
    'create trigger trg_auth_users_create_profile after insert on auth.users '
    'for each row execute function public.handle_new_auth_user_profile()';
end
$$;

commit;
