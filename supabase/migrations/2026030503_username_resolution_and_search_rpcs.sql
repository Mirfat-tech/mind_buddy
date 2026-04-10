grant usage on schema public to authenticated;

create or replace function public.get_usernames_by_ids(p_user_ids uuid[])
returns table(user_id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select p.id as user_id, p.username
  from public.profiles p
  where p.id = any(coalesce(p_user_ids, '{}'))
    and coalesce(p.username, '') <> '';
$$;

revoke all on function public.get_usernames_by_ids(uuid[]) from public;
grant execute on function public.get_usernames_by_ids(uuid[]) to authenticated;

create or replace function public.find_user_by_username(input_username text)
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.username
  from public.profiles p
  where lower(coalesce(p.username, '')) =
        lower(trim(both from trim(leading '@' from coalesce(input_username, ''))))
  limit 1;
$$;

revoke all on function public.find_user_by_username(text) from public;
grant execute on function public.find_user_by_username(text) to authenticated;

create or replace function public.search_usernames(prefix text, max_results int default 8)
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.username
  from public.profiles p
  where coalesce(p.username, '') <> ''
    and lower(p.username) like
      lower(trim(both from trim(leading '@' from coalesce(prefix, '')))) || '%'
  order by p.username asc
  limit greatest(1, least(coalesce(max_results, 8), 20));
$$;

revoke all on function public.search_usernames(text, int) from public;
grant execute on function public.search_usernames(text, int) to authenticated;
