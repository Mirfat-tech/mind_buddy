-- RLS-safe profile bootstrap helper for authenticated clients.
-- This allows clients to ensure a profile row exists without relying on
-- permissive INSERT policies on public.profiles.

begin;

create or replace function public.ensure_my_profile()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = v_uid;

  insert into public.profiles (id, email)
  values (v_uid, v_email)
  on conflict (id) do update
    set email = coalesce(excluded.email, public.profiles.email);
end;
$$;

alter function public.ensure_my_profile() owner to postgres;
revoke all on function public.ensure_my_profile() from public;
grant execute on function public.ensure_my_profile() to authenticated;

commit;
