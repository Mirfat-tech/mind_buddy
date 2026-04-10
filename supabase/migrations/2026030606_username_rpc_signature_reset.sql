-- Reset username RPCs to canonical signatures expected by the app and PostgREST.

drop function if exists public.get_usernames_by_ids(uuid[]);
drop function if exists public.search_usernames(text, integer);
drop function if exists public.find_user_by_username(text);

create or replace function public.get_usernames_by_ids(p_user_ids uuid[])
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.username
  from public.profiles p
  where p.id = any(p_user_ids)
    and p.username is not null;
$$;

create or replace function public.search_usernames(prefix text, max_results integer default 8)
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  with q as (
    select lower(trim(both from regexp_replace(prefix, '^@', ''))) as p
  )
  select p.id, p.username
  from public.profiles p, q
  where p.username is not null
    and lower(p.username) like (q.p || '%')
  order by length(p.username) asc, p.username asc
  limit max_results;
$$;

create or replace function public.find_user_by_username(input_username text)
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  with q as (
    select lower(trim(both from regexp_replace(input_username, '^@', ''))) as u
  )
  select p.id, p.username
  from public.profiles p, q
  where p.username is not null
    and lower(p.username) = q.u
  limit 1;
$$;

grant usage on schema public to authenticated;
grant execute on function public.get_usernames_by_ids(uuid[]) to authenticated;
grant execute on function public.search_usernames(text, integer) to authenticated;
grant execute on function public.find_user_by_username(text) to authenticated;
