begin;

-- Drop existing CHECK constraints on profiles.username so we can replace
-- legacy formats safely (idempotent across environments).
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'profiles'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%username%'
  loop
    execute format('alter table public.profiles drop constraint if exists %I', r.conname);
  end loop;
end
$$;

-- Canonical username rules:
-- - nullable (gate enforces requiredness in app flow)
-- - lowercase letters, digits, "_" and "."
-- - 3..20 chars
-- - must start/end with letter or digit
alter table public.profiles
  add constraint profiles_username_format_check
  check (
    username is null
    or username ~ '^[a-z0-9](?:[a-z0-9._]{1,18}[a-z0-9])$'
  );

commit;

