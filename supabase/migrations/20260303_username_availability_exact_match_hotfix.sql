begin;

create or replace function public.is_username_available(candidate text)
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

alter function public.is_username_available(text) owner to postgres;
revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to authenticated;
grant execute on function public.is_username_available(text) to service_role;

commit;

