-- Ensure authenticated users can read/update their own profile row.
alter table if exists public.profiles enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_own_completion_gate'
  ) then
    create policy profiles_select_own_completion_gate
      on public.profiles
      for select
      to authenticated
      using (auth.uid() = id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_own_completion_gate'
  ) then
    create policy profiles_update_own_completion_gate
      on public.profiles
      for update
      to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;

-- Optional: allow own-row upsert insert path when profile row does not exist yet.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_insert_own_completion_gate'
  ) then
    create policy profiles_insert_own_completion_gate
      on public.profiles
      for insert
      to authenticated
      with check (auth.uid() = id);
  end if;
end $$;
