drop function if exists public.find_user_by_username(text);

create or replace function public.find_user_by_username(input_username text)
returns table(user_id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select p.id as user_id, p.username
  from public.profiles p
  where lower(p.username) = lower(trim(leading '@' from input_username))
  limit 1;
$$;

revoke all on function public.find_user_by_username(text) from public;
grant execute on function public.find_user_by_username(text) to authenticated;
