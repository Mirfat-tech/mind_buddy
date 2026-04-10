begin;

create or replace function public.is_email_available_exact(candidate text)
returns boolean
language plpgsql
security definer
set search_path = public, auth, pg_catalog
as $$
declare
  normalized text;
begin
  normalized := lower(trim(coalesce(candidate, '')));

  if normalized = '' then
    return false;
  end if;

  return not exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized
  );
end;
$$;

alter function public.is_email_available_exact(text) owner to postgres;
revoke all on function public.is_email_available_exact(text) from public;
grant execute on function public.is_email_available_exact(text) to anon;
grant execute on function public.is_email_available_exact(text) to authenticated;
grant execute on function public.is_email_available_exact(text) to service_role;

commit;
