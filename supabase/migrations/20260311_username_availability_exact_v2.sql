begin;

create or replace function public.is_username_available_exact(candidate text)
returns boolean
language sql
security definer
set search_path = public, auth, pg_catalog
stable
as $$
  with normalized as (
    select lower(regexp_replace(btrim(coalesce(candidate, '')), '^@+', '')) as v
  )
  select
    case
      when (select v from normalized) = '' then false
      else not exists (
        select 1
        from public.profiles p
        where lower(btrim(coalesce(p.username, ''))) = (select v from normalized)
      )
    end;
$$;

alter function public.is_username_available_exact(text) owner to postgres;
revoke all on function public.is_username_available_exact(text) from public;
grant execute on function public.is_username_available_exact(text) to authenticated;
grant execute on function public.is_username_available_exact(text) to service_role;

commit;

