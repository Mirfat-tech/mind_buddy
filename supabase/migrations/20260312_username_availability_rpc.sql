begin;

create or replace function public.is_username_available(candidate text)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  normalized text;
begin
  normalized := lower(regexp_replace(coalesce(candidate, ''), '^@+', ''));

  if normalized = '' then
    return false;
  end if;

  return not exists (
    select 1
    from public.profiles p
    where lower(coalesce(p.username, '')) = normalized
  );
end;
$$;

alter function public.is_username_available(text) owner to postgres;
revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to authenticated;
grant execute on function public.is_username_available(text) to service_role;

commit;

