alter table public.journals
  add column if not exists doodle_updated_at timestamptz;

do $$
declare
  has_old_col boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'journals'
      and column_name = 'doodle_last_saved_at'
  ) into has_old_col;

  if has_old_col then
    execute '
      update public.journals
      set doodle_updated_at = coalesce(doodle_updated_at, doodle_last_saved_at)
      where doodle_last_saved_at is not null
    ';
  end if;
end
$$;
