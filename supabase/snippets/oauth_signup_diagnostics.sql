-- Run this in Supabase SQL Editor after reproducing OAuth signup.
-- 1) Trigger inventory on auth.users
select
  t.tgname as trigger_name,
  case t.tgenabled
    when 'O' then 'enabled'
    when 'D' then 'disabled'
    else t.tgenabled::text
  end as trigger_enabled,
  n.nspname as function_schema,
  p.proname as function_name,
  pg_get_triggerdef(t.oid) as trigger_def
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where t.tgrelid = 'auth.users'::regclass
  and not t.tgisinternal
order by t.tgname;

-- 2) Profile columns that are still NOT NULL (potential OAuth blockers)
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and is_nullable = 'NO'
order by ordinal_position;

-- 3) Constraints on public.profiles (check/unique/fk that can fail inserts)
select
  c.conname as constraint_name,
  c.contype as constraint_type,
  pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class r on r.oid = c.conrelid
join pg_namespace n on n.oid = r.relnamespace
where n.nspname = 'public'
  and r.relname = 'profiles'
order by c.contype, c.conname;

-- 4) Verify recent auth users have profile rows
select
  u.id,
  u.email,
  u.created_at,
  (p.id is not null) as has_profile,
  p.full_name,
  p.avatar_url
from auth.users u
left join public.profiles p on p.id = u.id
order by u.created_at desc
limit 20;
