alter table public.journals
  add column if not exists doodle_storage_path text,
  add column if not exists doodle_bg_style text,
  add column if not exists doodle_last_saved_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'journals_doodle_bg_style_check'
  ) then
    alter table public.journals
      add constraint journals_doodle_bg_style_check
      check (
        doodle_bg_style is null
        or doodle_bg_style in ('none', 'dots', 'lines', 'grid')
      );
  end if;
end
$$;
