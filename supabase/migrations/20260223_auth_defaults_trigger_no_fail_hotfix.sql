-- Hotfix: prevent legacy defaults trigger from blocking OAuth user creation.
-- Your auth.users currently has:
-- 1) on_auth_user_created_create_defaults -> public.handle_new_user_create_defaults
-- 2) trg_auth_users_create_profile       -> public.handle_new_auth_user_profile
--
-- If #1 throws, Supabase returns: "Database error saving new user".
-- This patch converts #1 into a no-fail trigger function.

begin;

create or replace function public.handle_new_user_create_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
begin
  -- Intentionally no-op.
  -- Keep legacy trigger attached, but never let it fail auth.users inserts.
  return new;
exception
  when others then
    raise warning
      'handle_new_user_create_defaults failed for user %, sqlstate=%, error=%',
      new.id, sqlstate, sqlerrm;
    return new;
end;
$$;

alter function public.handle_new_user_create_defaults() owner to postgres;

commit;
